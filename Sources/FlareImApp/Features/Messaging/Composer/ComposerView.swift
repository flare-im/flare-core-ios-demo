import FlareCoreAppleSDK
import AVFoundation
import AVKit
import SwiftUI
#if canImport(PhotosUI)
import PhotosUI
#endif

private enum ComposerPanel {
    case none
    case emoji
    case more
}

struct ComposerView: View {
    @EnvironmentObject private var messaging: MessagingViewModel
    @EnvironmentObject private var environment: AppEnvironment
    @Binding var text: String
    let conversation: AppConversation
    var expandedInputHeight: CGFloat = 360
    @State private var panel: ComposerPanel = .none
    @State private var richInputMode = false
    @State private var inputExpanded = false
    @State private var richAttributedText = RichTextMarkdownSerializer.emptyDocument()
    @State private var richSelection = RichTextComposerSelection()
    @State private var fileImporterOpen = false
    @State private var formDraft: ComposerFormDraft?
    @StateObject private var audioRecorder = ComposerAudioRecorder()
    @State private var voicePressActive = false
    @State private var voiceDragCancelling = false
    @State private var voiceCompletionInFlight = false
    private let voiceCancelDistance: CGFloat = 58
    #if canImport(PhotosUI)
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedVideoItem: PhotosPickerItem?
    @State private var videoPickerOpen = false
    #endif

    var body: some View {
        VStack(spacing: 0) {
            if !messaging.failedMessageKeys.isEmpty {
                ComposerStatusBanner(
                    symbol: "exclamationmark.triangle.fill",
                    message: String(localized: "\(messaging.failedMessageKeys.count) messages failed to send. Long-press a failed message to retry."),
                    tone: .danger
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else if messaging.runtimeStatus.isBlocking {
                ComposerStatusBanner(
                    symbol: messaging.runtimeStatus.productIcon,
                    message: messaging.lastError ?? messaging.runtimeStatus.productLabel,
                    tone: messaging.runtimeStatus.productTone
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            if let replyTarget = messaging.replyTarget {
                ComposerReplyBanner(message: replyTarget) {
                    messaging.clearReplyTarget()
                }
                .padding(.horizontal, FlareDesign.Spacing.xs)
                .padding(.top, FlareDesign.Spacing.sm)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            ZStack {
                // 版式对齐 Flutter（见 examples/COMPOSER-DESIGN-SPEC.md）：工具栏精确为 6 图标，
                // 「展开」与「发送」移至输入行尾部——iOS 多行输入无 IME 发送键，发送须显式按钮。
                HStack(alignment: .bottom, spacing: FlareDesign.Spacing.xs) {
                    composerInput
                        .disabled(messaging.runtimeStatus.isBlocking)
                        .onChange(of: text) { value in
                            Task { await messaging.setTyping(!value.isEmpty) }
                        }
                    if !richInputMode {
                        ComposerTool(
                            symbol: inputExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                            title: inputExpanded ? String(localized: "Collapse input") : String(localized: "Expand input"),
                            selected: inputExpanded
                        ) {
                            panel = .none
                            inputExpanded.toggle()
                        }
                        ComposerSendButton(enabled: canSend) {
                            sendCurrentText()
                        }
                    }
                }

                if audioRecorder.isRecording {
                    VoiceRecorderBar(
                        elapsed: audioRecorder.elapsedTime,
                        maximumDuration: ComposerAudioRecorder.maximumDuration,
                        isCancelling: voiceDragCancelling
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .bottom)))
                    .zIndex(1)
                }
            }
            .padding(.horizontal, FlareDesign.Spacing.xs)
            .padding(.top, FlareDesign.Spacing.sm)

            if !richInputMode {
                // 6 槽均分图标工具栏，对齐 Flutter：表情 / @提及 / 语音 / 图片 / 富文本 / 更多。
                HStack(spacing: 0) {
                    ComposerTool(symbol: "face.smiling", title: String(localized: "Emoji"), selected: panel == .emoji) {
                        toggle(.emoji)
                    }
                    .frame(maxWidth: .infinity)
                    ComposerTool(symbol: "at", title: String(localized: "Mention")) {
                        text += "@"
                    }
                    .frame(maxWidth: .infinity)
                    ComposerVoiceTool(
                        isRecording: audioRecorder.isRecording,
                        isCancelling: voiceDragCancelling,
                        onChanged: handleVoiceDragChanged,
                        onEnded: handleVoiceDragEnded
                    )
                    .frame(maxWidth: .infinity)
                    #if canImport(PhotosUI)
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        ComposerToolIcon(symbol: "photo", title: String(localized: "Image"))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Image"))
                    .frame(maxWidth: .infinity)
                    #else
                    ComposerTool(symbol: "photo", title: String(localized: "Image")) {
                        formDraft = ComposerFormDraft(kind: .imageFallback)
                    }
                    .frame(maxWidth: .infinity)
                    #endif
                    ComposerTextTool(title: String(localized: "Rich text"), selected: richInputMode) {
                        enterRichInputMode()
                    }
                    .frame(maxWidth: .infinity)
                    ComposerTool(symbol: panel == .more ? "xmark" : "plus.circle", title: String(localized: "More"), selected: panel == .more) {
                        toggle(.more)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, FlareDesign.Spacing.lg)
                .padding(.top, FlareDesign.Spacing.sm)
                .padding(.bottom, FlareDesign.Spacing.xxs)
            }

            if panel == .emoji {
                EmojiPanel(
                    onInsert: { value in text += value },
                    onSendSticker: { sticker in
                        panel = .none
                        var payload: [String: Any] = [
                            "stickerId": sticker.stickerId,
                            "packageId": sticker.packageId,
                            "format": "webp"
                        ]
                        if let url = EmojiPresentation.stickerURL(packageId: sticker.packageId, stickerId: sticker.stickerId) {
                            payload["url"] = url.absoluteString
                        }
                        Task { await messaging.buildAndSend(op: .createSticker, payload: payload) }
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if panel == .more {
                MoreComposerPanel(
                    onSelect: { item in
                        panel = .none
                        handleMoreItem(item)
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(
            FlareDesign.surfaceAlt
                .ignoresSafeArea(.container, edges: .bottom)
        )
        .animation(.easeOut(duration: 0.18), value: panel)
        .animation(.easeOut(duration: 0.18), value: richInputMode)
        .animation(.easeOut(duration: 0.18), value: inputExpanded)
        .animation(.easeOut(duration: 0.14), value: voiceDragCancelling)
        .onChange(of: audioRecorder.elapsedTime) { elapsed in
            handleVoiceDurationChange(elapsed)
        }
        #if canImport(PhotosUI)
        .onChange(of: selectedPhotoItem) { item in
            handleSelectedPhoto(item)
        }
        .onChange(of: selectedVideoItem) { item in
            handleSelectedVideo(item)
        }
        .photosPicker(isPresented: $videoPickerOpen, selection: $selectedVideoItem, matching: .videos)
        #endif
        .fileImporter(
            isPresented: $fileImporterOpen,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .sheet(item: $formDraft) { draft in
            ComposerInputFormSheet(draft: draft, currentUserId: messaging.currentUserId) { payload in
                Task { await messaging.buildAndSend(op: draft.kind.op, payload: payload) }
            }
            .presentationDetents([.height(draft.kind.preferredSheetHeight), .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var canSend: Bool {
        let hasContent: Bool
        if richInputMode {
            hasContent = !RichTextMarkdownSerializer.export(richAttributedText).plainText.isEmpty
        } else {
            hasContent = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return hasContent && !messaging.runtimeStatus.isBlocking
    }

    @ViewBuilder
    private var composerInput: some View {
        if richInputMode {
            RichComposerEditor(
                richText: $richAttributedText,
                selection: $richSelection,
                placeholder: String(localized: "Send rich text to \(conversation.appTitle)"),
                canSend: canSend,
                expanded: inputExpanded,
                expandedHeight: expandedInputHeight,
                onShortcut: toggleRichTextShortcut,
                onTextChange: { value in
                    text = value
                },
                onToggleExpanded: {
                    panel = .none
                    inputExpanded.toggle()
                },
                onExitRichText: {
                    text = RichTextMarkdownSerializer.export(richAttributedText).plainText
                    richInputMode = false
                },
                onSend: sendCurrentText
            )
        } else {
            EmojiAwareComposerInput(
                text: $text,
                placeholder: String(localized: "Send to \(conversation.appTitle)"),
                highlighted: panel != .none || inputExpanded,
                expanded: inputExpanded,
                expandedHeight: expandedInputHeight
            )
        }
    }

    private func toggle(_ next: ComposerPanel) {
        panel = panel == next ? .none : next
    }

    private func enterRichInputMode() {
        if !richInputMode {
            let plainDraft = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let richPlain = RichTextMarkdownSerializer.export(richAttributedText).plainText
            if richPlain != plainDraft {
                richAttributedText = plainDraft.isEmpty
                    ? RichTextMarkdownSerializer.emptyDocument()
                    : RichTextMarkdownSerializer.plainDocument(text)
            }
            richSelection = RichTextComposerSelection()
        }
        richInputMode = true
        panel = .none
    }

    private func resetRichDraft() {
        richAttributedText = RichTextMarkdownSerializer.emptyDocument()
        richSelection = RichTextComposerSelection()
    }

    private func sendCurrentText() {
        panel = .none

        if richInputMode {
            let export = RichTextMarkdownSerializer.export(richAttributedText)
            guard !export.plainText.isEmpty else { return }
            Task {
                let sent: Bool
                if let replyTarget = messaging.replyTarget {
                    sent = await messaging.sendReplyText(export.plainText, replyingTo: replyTarget)
                } else {
                    sent = await messaging.buildAndSend(
                        op: .createRichDoc,
                        payload: [
                            "markdown": export.markdown,
                            "plainText": export.plainText,
                            "searchText": export.searchText,
                            "title": export.title
                        ]
                    )
                }
                if sent {
                    text = ""
                    resetRichDraft()
                } else {
                    let fallbackSent = await messaging.sendText(export.plainText)
                    text = fallbackSent ? "" : export.plainText
                    if fallbackSent {
                        resetRichDraft()
                    }
                }
            }
            return
        }

        let outbound = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !outbound.isEmpty else { return }
        if let replyTarget = messaging.replyTarget {
            Task {
                let sent = await messaging.sendReplyText(outbound, replyingTo: replyTarget)
                text = sent ? "" : outbound
            }
            return
        }
        if let emojiKey = EmojiPresentation.lonePackKey(in: outbound) {
            Task {
                let sent = await messaging.buildAndSend(op: .createEmoji, payload: ["emoji": emojiKey])
                text = sent ? "" : outbound
            }
        } else {
            Task {
                let sent = await messaging.sendText(outbound)
                text = sent ? "" : outbound
            }
        }
    }

    private func toggleRichTextShortcut(_ shortcut: RichTextShortcut) {
        richSelection.toggle(shortcut)
    }

    private func handleVoiceDragChanged(_ value: DragGesture.Value) {
        guard !voiceCompletionInFlight else { return }
        if !voicePressActive {
            voicePressActive = true
            voiceDragCancelling = false
            startVoiceRecording()
        }
        voiceDragCancelling = value.translation.height <= -voiceCancelDistance
    }

    private func handleVoiceDragEnded(_ value: DragGesture.Value) {
        let shouldCancel = value.translation.height <= -voiceCancelDistance || voiceDragCancelling
        voicePressActive = false
        voiceDragCancelling = false
        if shouldCancel {
            cancelVoiceRecording()
        } else {
            finishVoiceRecording()
        }
    }

    private func handleVoiceDurationChange(_ elapsed: TimeInterval) {
        guard audioRecorder.isRecording,
              elapsed >= ComposerAudioRecorder.maximumDuration,
              !voiceCompletionInFlight else {
            return
        }
        voicePressActive = false
        if voiceDragCancelling {
            cancelVoiceRecording()
        } else {
            finishVoiceRecording()
        }
        voiceDragCancelling = false
    }

    private func handleMoreItem(_ item: ComposerMoreItem) {
        switch item.kind {
        case .file:
            fileImporterOpen = true
        case .video:
            #if canImport(PhotosUI)
            videoPickerOpen = true
            #else
            formDraft = ComposerFormDraft(kind: .video)
            #endif
        case .location:
            formDraft = ComposerFormDraft(kind: .location)
        case .card:
            formDraft = ComposerFormDraft(kind: .card)
        case .task:
            formDraft = ComposerFormDraft(kind: .task)
        case .schedule:
            formDraft = ComposerFormDraft(kind: .schedule)
        case .poll:
            formDraft = ComposerFormDraft(kind: .poll)
        case .link:
            formDraft = ComposerFormDraft(kind: .link)
        case .miniProgram:
            formDraft = ComposerFormDraft(kind: .miniProgram)
        case .topic:
            text = text.isEmpty ? "#话题 " : "\(text) #话题 "
        case .notification:
            formDraft = ComposerFormDraft(kind: .notification)
        case .announcement:
            formDraft = ComposerFormDraft(kind: .announcement)
        }
    }

    #if canImport(PhotosUI)
    private func handleSelectedPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        selectedPhotoItem = nil
        panel = .none
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { return }
                let payload = try persistSelectedImagePayload(data: data, item: item)
                let uploadedPayload = try await messaging.uploadImageAttachmentPayload(payload)
                await messaging.buildAndSend(op: .createImage, payload: uploadedPayload)
            } catch {
                environment.appendLab(
                    "composer.image",
                    status: "error",
                    detail: FlareFormatters.errorText(error)
                )
            }
        }
    }

    private func persistSelectedImagePayload(data: Data, item: PhotosPickerItem) throws -> [String: Any] {
        let id = "local-image-\(UUID().uuidString)"
        let contentType = item.supportedContentTypes.first
        let fileExtension = contentType?.preferredFilenameExtension ?? "jpg"
        let fileURL = try composerMediaDirectory().appendingPathComponent("\(id).\(fileExtension)")
        try data.write(to: fileURL, options: [.atomic])

        var payload: [String: Any] = [
            "imageId": id,
            "localPath": fileURL.path,
            "sourceUrl": fileURL.absoluteString,
            "mimeType": contentType?.preferredMIMEType ?? "image/jpeg",
            "size": data.count
        ]
        if let size = platformImageSize(data: data) {
            payload["width"] = size.width
            payload["height"] = size.height
        }
        return payload
    }

    private func handleSelectedVideo(_ item: PhotosPickerItem?) {
        guard let item else { return }
        selectedVideoItem = nil
        panel = .none
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { return }
                let payload = try await persistSelectedVideoPayload(data: data, item: item)
                await messaging.buildAndSend(op: .createVideo, payload: payload)
            } catch {
                environment.appendLab(
                    "composer.video",
                    status: "error",
                    detail: FlareFormatters.errorText(error)
                )
            }
        }
    }

    private func persistSelectedVideoPayload(data: Data, item: PhotosPickerItem) async throws -> [String: Any] {
        let id = "local-video-\(UUID().uuidString)"
        let contentType = item.supportedContentTypes.first(where: { $0.conforms(to: .movie) }) ?? item.supportedContentTypes.first
        let fileExtension = contentType?.preferredFilenameExtension ?? "mp4"
        let fileURL = try composerMediaDirectory().appendingPathComponent("\(id).\(fileExtension)")
        try data.write(to: fileURL, options: [.atomic])

        var payload: [String: Any] = [
            "videoId": id,
            "description": fileURL.lastPathComponent,
            "sourceUrl": fileURL.absoluteString,
            "mimeType": contentType?.preferredMIMEType ?? "video/mp4",
            "size": data.count
        ]
        if let durationMs = await mediaDurationMs(url: fileURL) {
            payload["durationMs"] = durationMs
        }
        return payload
    }
    #endif

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            panel = .none
            Task {
                let didAccess = url.startAccessingSecurityScopedResource()
                defer {
                    if didAccess {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                do {
                    let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentTypeKey, .localizedNameKey])
                    let fileId = "local-file-\(UUID().uuidString)"
                    let cachedURL = try copyFileToComposerCache(
                        sourceURL: url,
                        id: fileId,
                        preferredExtension: url.pathExtension
                    )
                    let cachedValues = try cachedURL.resourceValues(forKeys: [.fileSizeKey])
                    var payload: [String: Any] = [
                        "fileId": fileId,
                        "fileName": values.localizedName ?? url.lastPathComponent,
                        "url": cachedURL.absoluteString
                    ]
                    if let size = cachedValues.fileSize ?? values.fileSize {
                        payload["size"] = size
                    }
                    if let mimeType = values.contentType?.preferredMIMEType {
                        payload["mimeType"] = mimeType
                    }
                    await messaging.buildAndSend(op: .createFile, payload: payload)
                } catch {
                    environment.appendLab(
                        "composer.file",
                        status: "error",
                        detail: FlareFormatters.errorText(error)
                    )
                }
            }
        case .failure(let error):
            environment.appendLab(
                "composer.file",
                status: "error",
                detail: FlareFormatters.errorText(error)
            )
        }
    }

    private func startVoiceRecording() {
        guard !audioRecorder.isRecording else { return }
        panel = .none
        Task {
            do {
                try await audioRecorder.start()
                if !voicePressActive && !voiceCompletionInFlight {
                    audioRecorder.cancel()
                }
            } catch {
                environment.appendLab(
                    "composer.audio.start",
                    status: "error",
                    detail: FlareFormatters.errorText(error)
                )
            }
        }
    }

    private func finishVoiceRecording() {
        guard audioRecorder.isRecording, !voiceCompletionInFlight else { return }
        voiceCompletionInFlight = true
        voicePressActive = false
        voiceDragCancelling = false
        Task {
            defer {
                voiceCompletionInFlight = false
            }
            do {
                guard let payload = try audioRecorder.finish() else { return }
                let uploadedPayload = try await messaging.uploadAudioAttachmentPayload(payload)
                await messaging.buildAndSend(op: .createAudio, payload: uploadedPayload)
            } catch {
                environment.appendLab(
                    "composer.audio.finish",
                    status: "error",
                    detail: FlareFormatters.errorText(error)
                )
            }
        }
    }

    private func cancelVoiceRecording() {
        voicePressActive = false
        voiceDragCancelling = false
        voiceCompletionInFlight = false
        audioRecorder.cancel()
    }

}

private struct ComposerReplyBanner: View {
    let message: AppMessage
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: FlareDesign.Spacing.sm) {
            RoundedRectangle(cornerRadius: 2)
                .fill(FlareDesign.brand)
                .frame(width: 3, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(message.senderTitle)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(FlareDesign.brand)
                    .lineLimit(1)
                Text(message.previewText)
                    .font(.caption)
                    .foregroundStyle(FlareDesign.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: FlareDesign.Spacing.sm)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(FlareDesign.textSecondary)
                    .frame(width: 26, height: 26)
                    .background(FlareDesign.surfaceAlt)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, FlareDesign.Spacing.md)
        .padding(.vertical, FlareDesign.Spacing.sm)
        .background(FlareDesign.surface)
        .clipShape(RoundedRectangle(cornerRadius: FlareDesign.Radius.medium, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 4)
    }
}
