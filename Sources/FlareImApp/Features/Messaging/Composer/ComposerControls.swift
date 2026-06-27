import FlareCoreAppleSDK
import AVFoundation
import AVKit
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ComposerStatusBanner: View {
    let symbol: String
    let message: String
    let tone: RuntimeTone

    var body: some View {
        HStack(spacing: FlareDesign.Spacing.sm) {
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(iconColor)
            Text(message)
                .font(.caption.weight(.semibold))
                .foregroundStyle(FlareDesign.textSecondary)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, FlareDesign.Spacing.md)
        .padding(.vertical, FlareDesign.Spacing.sm)
        .background(backgroundColor)
    }

    private var iconColor: Color {
        switch tone {
        case .danger: return FlareDesign.danger
        case .warning: return FlareDesign.warning
        case .success: return FlareDesign.success
        default: return FlareDesign.brand
        }
    }

    private var backgroundColor: Color {
        switch tone {
        case .danger: return FlareDesign.danger.opacity(0.10)
        case .warning: return FlareDesign.warning.opacity(0.12)
        case .success: return FlareDesign.success.opacity(0.10)
        default: return FlareDesign.brandSoft
        }
    }
}

struct VoiceRecorderBar: View {
    let elapsed: TimeInterval
    let maximumDuration: TimeInterval
    let isCancelling: Bool

    var body: some View {
        VStack(spacing: FlareDesign.Spacing.sm) {
            HStack(spacing: FlareDesign.Spacing.md) {
                Image(systemName: isCancelling ? "xmark.circle.fill" : "waveform")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(isCancelling ? FlareDesign.danger : FlareDesign.brand)
                    .frame(width: 36, height: 36)
                    .background((isCancelling ? FlareDesign.danger : FlareDesign.brand).opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(isCancelling ? "松手取消" : "松开发送")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(FlareDesign.textPrimary)
                    Text(isCancelling ? "下滑恢复发送" : "上滑取消")
                        .font(.caption)
                        .foregroundStyle(FlareDesign.textSecondary)
                }

                Spacer(minLength: FlareDesign.Spacing.sm)

                Text("\(format(elapsed)) / \(format(maximumDuration))")
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(isCancelling ? FlareDesign.danger : FlareDesign.textSecondary)
            }

            GeometryReader { proxy in
                Capsule(style: .continuous)
                    .fill(Color.black.opacity(0.08))
                    .overlay(alignment: .leading) {
                        Capsule(style: .continuous)
                            .fill(isCancelling ? FlareDesign.danger : FlareDesign.brand)
                            .frame(width: proxy.size.width * progress)
                    }
            }
            .frame(height: 3)
        }
        .frame(maxWidth: .infinity, minHeight: 54)
        .padding(.horizontal, FlareDesign.Spacing.md)
        .padding(.vertical, FlareDesign.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: FlareDesign.Radius.large, style: .continuous)
                .fill(FlareDesign.surface)
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
        )
        .overlay {
            RoundedRectangle(cornerRadius: FlareDesign.Radius.large, style: .continuous)
                .stroke((isCancelling ? FlareDesign.danger : FlareDesign.brand).opacity(0.22), lineWidth: 1)
        }
    }

    private func format(_ elapsed: TimeInterval) -> String {
        let totalSeconds = max(0, Int(elapsed.rounded()))
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    private var progress: CGFloat {
        guard maximumDuration > 0 else { return 0 }
        return CGFloat(min(1, max(0, elapsed / maximumDuration)))
    }
}

struct ComposerVoiceTool: View {
    let isRecording: Bool
    let isCancelling: Bool
    let onChanged: (DragGesture.Value) -> Void
    let onEnded: (DragGesture.Value) -> Void

    var body: some View {
        Image(systemName: isRecording ? (isCancelling ? "xmark" : "mic.fill") : "mic")
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(iconColor)
            .frame(width: 30, height: 30)
            .background(iconBackground)
            .clipShape(Circle())
        .scaleEffect(isRecording ? 1.08 : 1)
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged(onChanged)
                .onEnded(onEnded)
        )
        .accessibilityLabel(Text("Hold to record voice"))
    }

    private var iconColor: Color {
        if isCancelling { return FlareDesign.danger }
        return isRecording ? FlareDesign.brand : FlareDesign.textSecondary
    }

    private var iconBackground: Color {
        if isCancelling { return FlareDesign.danger.opacity(0.12) }
        return isRecording ? FlareDesign.brandSoft : Color.clear
    }
}

struct ComposerTool: View {
    let symbol: String
    let title: String
    var selected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ComposerToolIcon(symbol: symbol, title: title, selected: selected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

struct ComposerToolIcon: View {
    let symbol: String
    let title: String
    var selected = false

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(selected ? FlareDesign.brand : FlareDesign.textSecondary)
            .frame(width: 30, height: 30)
            .background(selected ? FlareDesign.brandSoft : Color.clear)
            .clipShape(Circle())
            .accessibilityLabel(title)
    }
}

struct ComposerTextTool: View {
    let title: String
    var selected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Aa")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(selected ? FlareDesign.brand : FlareDesign.textSecondary)
                .frame(width: 30, height: 30)
                .background(selected ? FlareDesign.brandSoft : Color.clear)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

struct ComposerSendButton: View {
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "paperplane.fill")
                .font(FlareDesign.Typography.title)
                .foregroundStyle(enabled ? FlareDesign.brand : FlareDesign.brand.opacity(0.30))
                .rotationEffect(.degrees(45))
                .frame(width: 42, height: 38)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(Text("Send"))
    }
}

enum RichTextShortcut: String, CaseIterable, Identifiable {
    case heading
    case bold
    case italic
    case strike
    case quote
    case bulletList
    case orderedList
    case codeBlock
    case inlineCode
    case link
    case image
    case mention

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .heading: return "textformat.size"
        case .bold: return "bold"
        case .italic: return "italic"
        case .strike: return "strikethrough"
        case .quote: return "quote.opening"
        case .bulletList: return "list.bullet"
        case .orderedList: return "list.number"
        case .codeBlock: return "chevron.left.forwardslash.chevron.right"
        case .inlineCode: return "curlybraces"
        case .link: return "link"
        case .image: return "photo"
        case .mention: return "at"
        }
    }

    var title: String {
        switch self {
        case .heading: return String(localized: "Title")
        case .bold: return String(localized: "Bold")
        case .italic: return String(localized: "Italic")
        case .strike: return String(localized: "Strikethrough")
        case .quote: return String(localized: "Quote")
        case .bulletList: return String(localized: "Bulleted list")
        case .orderedList: return String(localized: "Numbered list")
        case .codeBlock: return String(localized: "Code block")
        case .inlineCode: return String(localized: "Inline code")
        case .link: return String(localized: "Link")
        case .image: return String(localized: "Image syntax")
        case .mention: return String(localized: "Mention")
        }
    }
}

struct RichComposerEditor: View {
    @Binding var richText: NSAttributedString
    @Binding var selection: RichTextComposerSelection
    let placeholder: String
    let canSend: Bool
    let expanded: Bool
    let expandedHeight: CGFloat
    let onShortcut: (RichTextShortcut) -> Void
    let onTextChange: (String) -> Void
    let onToggleExpanded: () -> Void
    let onExitRichText: () -> Void
    let onSend: () -> Void

    private let toolbarShortcuts: [RichTextShortcut] = [
        .heading,
        .bold,
        .strike,
        .italic,
        .bulletList,
        .orderedList,
        .quote,
        .codeBlock,
        .link,
        .image,
        .mention
    ]

    var body: some View {
        VStack(spacing: 0) {
            RichTextEditingSurface(
                attributedText: $richText,
                selection: $selection,
                placeholder: placeholder,
                expanded: expanded,
                expandedHeight: expandedHeight,
                onTextChange: onTextChange
            )

            Divider()
                .opacity(0.32)

            HStack(spacing: FlareDesign.Spacing.xs) {
                Button(action: onToggleExpanded) {
                    Image(systemName: expanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(FlareDesign.brand)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(expanded ? "Collapse input" : "Expand input"))

                Button(action: onExitRichText) {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(FlareDesign.brand)
                        .frame(width: 29, height: 29)
                        .background(FlareDesign.brandSoft)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Plain text input"))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: FlareDesign.Spacing.xs) {
                        ForEach(toolbarShortcuts) { shortcut in
                            Button {
                                onShortcut(shortcut)
                            } label: {
                                RichToolbarGlyph(shortcut: shortcut, selected: selection.isActive(shortcut))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(shortcut.title)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button(action: onSend) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(canSend ? FlareDesign.brand : FlareDesign.brand.opacity(0.30))
                        .rotationEffect(.degrees(45))
                        .frame(width: 34, height: 30)
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .accessibilityLabel(Text("Send"))
            }
            .padding(.horizontal, FlareDesign.Spacing.xs)
            .padding(.vertical, FlareDesign.Spacing.sm)
            .background(FlareDesign.surfaceAlt)
        }
        .background(FlareDesign.surface)
        .clipShape(RoundedRectangle(cornerRadius: FlareDesign.Radius.large, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: -2)
    }
}

private struct RichTextEditingSurface: View {
    @Binding var attributedText: NSAttributedString
    @Binding var selection: RichTextComposerSelection
    let placeholder: String
    let expanded: Bool
    let expandedHeight: CGFloat
    let onTextChange: (String) -> Void

    private var editorMinHeight: CGFloat {
        expanded ? max(240, expandedHeight) : 132
    }

    private var editorMaxHeight: CGFloat {
        expanded ? max(240, expandedHeight) : 180
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            editor
            if attributedText.string.isEmpty {
                Text(placeholder)
                    .font(.body)
                    .foregroundStyle(FlareDesign.textTertiary)
                    .padding(.horizontal, FlareDesign.Spacing.lg)
                    .padding(.vertical, FlareDesign.Spacing.lg)
                .allowsHitTesting(false)
            }
        }
        .frame(minHeight: editorMinHeight, maxHeight: editorMaxHeight)
    }

    @ViewBuilder
    private var editor: some View {
        #if canImport(UIKit)
        RichTextUIKitEditor(
            attributedText: $attributedText,
            selection: $selection,
            onTextChange: onTextChange
        )
        .frame(minHeight: editorMinHeight, maxHeight: editorMaxHeight)
        #else
        TextEditor(text: plainTextBinding)
            .font(.body)
            .foregroundStyle(FlareDesign.textPrimary)
            .tint(FlareDesign.brand)
            .scrollContentBackground(.hidden)
            .padding(.horizontal, FlareDesign.Spacing.sm)
            .padding(.vertical, FlareDesign.Spacing.sm)
            .frame(minHeight: editorMinHeight, maxHeight: editorMaxHeight)
        #endif
    }

    private var plainTextBinding: Binding<String> {
        Binding(
            get: { attributedText.string },
            set: { value in
                attributedText = NSAttributedString(
                    string: value,
                    attributes: RichTextMarkdownSerializer.attributes(for: selection)
                )
                onTextChange(value)
            }
        )
    }
}

#if canImport(UIKit)
private struct RichTextUIKitEditor: UIViewRepresentable {
    @Binding var attributedText: NSAttributedString
    @Binding var selection: RichTextComposerSelection
    let onTextChange: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.isAccessibilityElement = true
        textView.accessibilityLabel = String(localized: "Rich text input")
        textView.accessibilityIdentifier = "flare.richTextEditor"
        textView.adjustsFontForContentSizeCategory = true
        textView.isScrollEnabled = true
        textView.keyboardDismissMode = .interactive
        textView.textContainerInset = UIEdgeInsets(
            top: FlareDesign.Spacing.md,
            left: FlareDesign.Spacing.md,
            bottom: FlareDesign.Spacing.md,
            right: FlareDesign.Spacing.md
        )
        textView.textContainer.lineFragmentPadding = 0
        textView.attributedText = attributedText
        applySelection(to: textView)
        DispatchQueue.main.async {
            textView.becomeFirstResponder()
        }
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.parent = self
        if !context.coordinator.isUpdatingFromTextView,
           !textView.attributedText.isEqual(to: attributedText) {
            let selectedRange = textView.selectedRange
            textView.attributedText = attributedText
            textView.selectedRange = clampedRange(selectedRange, length: textView.attributedText.length)
        }
        applySelection(to: textView)
        textView.accessibilityValue = textView.attributedText.string
    }

    private func applySelection(to textView: UITextView) {
        textView.typingAttributes = RichTextMarkdownSerializer.attributes(for: selection)
        if textView.window != nil, !textView.isFirstResponder {
            DispatchQueue.main.async {
                textView.becomeFirstResponder()
            }
        }
    }

    private func clampedRange(_ range: NSRange, length: Int) -> NSRange {
        let location = min(max(0, range.location), length)
        return NSRange(location: location, length: min(range.length, max(0, length - location)))
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: RichTextUIKitEditor
        var isUpdatingFromTextView = false

        init(_ parent: RichTextUIKitEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            isUpdatingFromTextView = true
            parent.attributedText = textView.attributedText ?? RichTextMarkdownSerializer.emptyDocument()
            parent.onTextChange(textView.text ?? "")
            isUpdatingFromTextView = false
        }
    }
}
#endif

private struct RichToolbarGlyph: View {
    let shortcut: RichTextShortcut
    let selected: Bool

    var body: some View {
        glyph
            .foregroundStyle(selected ? FlareDesign.brand : FlareDesign.textSecondary)
            .frame(width: 29, height: 29)
            .background(selected ? FlareDesign.brandSoft : FlareDesign.surface)
            .clipShape(Circle())
    }

    @ViewBuilder
    private var glyph: some View {
        switch shortcut {
        case .heading:
            Text("Aa")
                .font(.system(size: 15, weight: .semibold))
        case .bold:
            Text("B")
                .font(.system(size: 16, weight: .semibold))
        case .italic:
            Text("I")
                .font(.system(size: 16, weight: .semibold))
                .italic()
        case .strike:
            Text("S")
                .font(.system(size: 16, weight: .semibold))
                .strikethrough()
        default:
            Image(systemName: shortcut.symbol)
                .font(.system(size: 14, weight: .semibold))
        }
    }
}

struct RichMarkdownView: View {
    let markdown: String
    var outgoing = false
    var compact = false

    private var lines: [String] {
        markdown
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? FlareDesign.Spacing.xs : FlareDesign.Spacing.sm) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                lineView(line)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func lineView(_ line: String) -> some View {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            Color.clear
                .frame(height: FlareDesign.Spacing.xs)
        } else if trimmed.hasPrefix("## ") {
            Text(inlineText(String(trimmed.dropFirst(3))))
                .font(compact ? .headline.weight(.semibold) : .title3.weight(.semibold))
                .foregroundStyle(primaryColor)
        } else if trimmed.hasPrefix("# ") {
            Text(inlineText(String(trimmed.dropFirst(2))))
                .font(compact ? .headline.weight(.semibold) : .title2.weight(.semibold))
                .foregroundStyle(primaryColor)
        } else if trimmed.hasPrefix("> ") {
            HStack(alignment: .top, spacing: FlareDesign.Spacing.sm) {
                RoundedRectangle(cornerRadius: FlareDesign.Radius.pill, style: .continuous)
                    .fill(outgoing ? Color.white.opacity(0.62) : FlareDesign.brand.opacity(0.55))
                    .frame(width: 3)
                Text(inlineText(String(trimmed.dropFirst(2))))
                    .font(FlareDesign.Typography.body)
                    .foregroundStyle(secondaryColor)
            }
        } else if trimmed.hasPrefix("- ") {
            HStack(alignment: .firstTextBaseline, spacing: FlareDesign.Spacing.sm) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 5, weight: .bold))
                    .foregroundStyle(outgoing ? Color.white.opacity(0.88) : FlareDesign.brand)
                Text(inlineText(String(trimmed.dropFirst(2))))
                    .font(FlareDesign.Typography.body)
                    .foregroundStyle(primaryColor)
            }
        } else if let range = trimmed.range(of: #"^\d+\.\s+"#, options: .regularExpression) {
            let marker = String(trimmed[..<range.upperBound]).trimmingCharacters(in: .whitespaces)
            let content = String(trimmed[range.upperBound...])
            HStack(alignment: .firstTextBaseline, spacing: FlareDesign.Spacing.sm) {
                Text(marker)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(outgoing ? Color.white.opacity(0.88) : FlareDesign.brand)
                    .frame(minWidth: 20, alignment: .trailing)
                Text(inlineText(content))
                    .font(FlareDesign.Typography.body)
                    .foregroundStyle(primaryColor)
            }
        } else if trimmed.hasPrefix("```") {
            Text(trimmed.replacingOccurrences(of: "`", with: ""))
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(secondaryColor)
                .padding(.horizontal, FlareDesign.Spacing.sm)
                .padding(.vertical, FlareDesign.Spacing.xs)
                .background(outgoing ? Color.white.opacity(0.14) : FlareDesign.surfaceAlt)
                .clipShape(RoundedRectangle(cornerRadius: FlareDesign.Radius.small, style: .continuous))
        } else {
            Text(inlineText(line))
                .font(FlareDesign.Typography.body)
                .foregroundStyle(primaryColor)
        }
    }

    private var primaryColor: Color {
        outgoing ? FlareDesign.outgoingText : FlareDesign.textPrimary
    }

    private var secondaryColor: Color {
        outgoing ? FlareDesign.outgoingText.opacity(0.78) : FlareDesign.textSecondary
    }

    private func inlineText(_ value: String) -> AttributedString {
        if let parsed = try? AttributedString(markdown: cleanedInlineSource(value)) {
            return parsed
        }
        return AttributedString(cleanedInlineSource(value))
    }

    private func cleanedInlineSource(_ value: String) -> String {
        var output = value
        let replacements: [(String, String)] = [
            (#"~~([^~]+)~~"#, "$1"),
            (#"!\[([^\]]*)\]\(([^)]+)\)"#, "$1"),
            (#"\[([^\]]+)\]\(([^)]+)\)"#, "$1")
        ]
        for (pattern, replacement) in replacements {
            output = output.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
        }
        return output
    }
}

struct EmojiAwareComposerInput: View {
    @Binding var text: String
    let placeholder: String
    let highlighted: Bool
    let expanded: Bool
    let expandedHeight: CGFloat

    private var inputMinHeight: CGFloat {
        expanded ? max(240, expandedHeight) : 0
    }

    private var inputMaxHeight: CGFloat? {
        expanded ? max(240, expandedHeight) : nil
    }

    private var segments: [EmojiPresentation.DisplaySegment] {
        EmojiPresentation.displaySegments(in: text)
    }

    private var shouldRenderPreview: Bool {
        EmojiPresentation.hasDisplayEmoji(in: text)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(expanded ? 8...24 : 1...4)
                .foregroundStyle(shouldRenderPreview ? Color.clear : FlareDesign.textPrimary)
                .tint(FlareDesign.brand)
                .padding(.horizontal, FlareDesign.Spacing.lg)
                .padding(.vertical, FlareDesign.Spacing.md)
                .frame(maxWidth: .infinity, minHeight: inputMinHeight, maxHeight: inputMaxHeight, alignment: .topLeading)

            if shouldRenderPreview {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: FlareDesign.Spacing.xs) {
                        ForEach(segments) { segment in
                            segmentView(segment)
                        }
                    }
                    .padding(.trailing, FlareDesign.Spacing.sm)
                }
                .padding(.horizontal, FlareDesign.Spacing.lg)
                .padding(.vertical, expanded ? FlareDesign.Spacing.md : FlareDesign.Spacing.sm)
                .frame(maxWidth: .infinity, minHeight: inputMinHeight, maxHeight: inputMaxHeight, alignment: .topLeading)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FlareDesign.surface)
        .clipShape(RoundedRectangle(cornerRadius: FlareDesign.Radius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FlareDesign.Radius.large, style: .continuous)
                .stroke(highlighted ? FlareDesign.brand.opacity(0.35) : Color.black.opacity(0.06), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func segmentView(_ segment: EmojiPresentation.DisplaySegment) -> some View {
        switch segment.kind {
        case .text(let value):
            Text(value.replacingOccurrences(of: "\n", with: " "))
                .font(.body)
                .foregroundStyle(FlareDesign.textPrimary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        case .emoji(let key):
            FlareAssetImageView(
                url: EmojiPresentation.emojiURL(for: key),
                fallbackSystemImage: "face.smiling",
                accessibilityLabel: key,
                size: 28,
                travel: 0,
                rotation: 0,
                isAnimated: false
            )
            .frame(width: 34, height: 32)
            .background(FlareDesign.brandSoft.opacity(0.75))
            .clipShape(RoundedRectangle(cornerRadius: FlareDesign.Radius.medium, style: .continuous))
        }
    }
}

private enum EmojiPanelMode {
    case emoji
    case stickers
}

struct EmojiPanel: View {
    let onInsert: (String) -> Void
    let onSendSticker: (StickerAsset) -> Void

    @State private var mode: EmojiPanelMode = .emoji

    private let emojis = EmojiPresentation.composerEmojiKeys
    private let stickers = EmojiPresentation.composerStickers

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: FlareDesign.Spacing.md) {
                    switch mode {
                    case .emoji:
                        emojiSections
                    case .stickers:
                        stickerSection
                    }
                }
                .padding(.horizontal, FlareDesign.Spacing.md)
                .padding(.top, FlareDesign.Spacing.md)
                .padding(.bottom, FlareDesign.Spacing.md)
            }
            .frame(height: 218)

            modeBar
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FlareDesign.surface)
    }

    private var emojiColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: FlareDesign.Spacing.lg), count: 6)
    }

    private var stickerColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: FlareDesign.Spacing.md), count: 5)
    }

    private var emojiSections: some View {
        VStack(alignment: .leading, spacing: FlareDesign.Spacing.md) {
            Text("最常使用")
                .font(.caption.weight(.bold))
                .foregroundStyle(FlareDesign.textSecondary)

            LazyVGrid(columns: emojiColumns, spacing: FlareDesign.Spacing.lg) {
                ForEach(Array(emojis.prefix(11)), id: \.self) { key in
                    emojiButton(key)
                }
            }

            Text("默认表情")
                .font(.caption.weight(.bold))
                .foregroundStyle(FlareDesign.textSecondary)
                .padding(.top, FlareDesign.Spacing.xxs)

            LazyVGrid(columns: emojiColumns, spacing: FlareDesign.Spacing.lg) {
                ForEach(Array(emojis.dropFirst(11)), id: \.self) { key in
                    emojiButton(key)
                }
            }
        }
    }

    private var stickerSection: some View {
        VStack(alignment: .leading, spacing: FlareDesign.Spacing.md) {
            Text("头像贴纸")
                .font(.caption.weight(.bold))
                .foregroundStyle(FlareDesign.textSecondary)

            LazyVGrid(columns: stickerColumns, spacing: FlareDesign.Spacing.md) {
                ForEach(stickers) { sticker in
                    stickerButton(sticker, size: 45)
                }
            }
        }
    }

    private var modeBar: some View {
        HStack(spacing: FlareDesign.Spacing.md) {
            Button {
                mode = .emoji
            } label: {
                Image(systemName: "face.smiling")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(mode == .emoji ? FlareDesign.brand : FlareDesign.textSecondary)
                    .frame(width: 34, height: 34)
                    .background(mode == .emoji ? FlareDesign.brandSoft : Color.clear)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("默认表情"))

            ForEach(Array(stickers.prefix(2))) { sticker in
                Button {
                    mode = .stickers
                } label: {
                    FlareAssetImageView(
                        url: EmojiPresentation.stickerURL(packageId: sticker.packageId, stickerId: sticker.stickerId),
                        fallbackSystemImage: "rectangle.stack.fill",
                        accessibilityLabel: sticker.id,
                        size: 26,
                        travel: 0,
                        rotation: 0,
                        isAnimated: false
                    )
                    .frame(width: 34, height: 34)
                    .background(mode == .stickers ? FlareDesign.brandSoft : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: FlareDesign.Radius.medium, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("头像贴纸"))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, FlareDesign.Spacing.lg)
        .padding(.vertical, FlareDesign.Spacing.sm)
        .background(FlareDesign.surfaceAlt)
    }

    private func emojiButton(_ key: String) -> some View {
        Button {
            onInsert("[\(key)]")
        } label: {
            FlareAssetImageView(
                url: EmojiPresentation.emojiURL(for: key),
                fallbackSystemImage: "face.smiling",
                accessibilityLabel: key,
                size: 31,
                travel: 0,
                rotation: 0,
                isAnimated: false
            )
            .frame(width: 44, height: 36)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(key)
    }

    private func stickerButton(_ sticker: StickerAsset, size: CGFloat) -> some View {
        Button {
            onSendSticker(sticker)
        } label: {
            FlareAssetImageView(
                url: EmojiPresentation.stickerURL(packageId: sticker.packageId, stickerId: sticker.stickerId),
                fallbackSystemImage: "rectangle.stack.fill",
                accessibilityLabel: sticker.id,
                size: size,
                travel: 0,
                rotation: 0,
                isAnimated: false
            )
            .frame(width: 56, height: 54)
            .background(FlareDesign.surfaceAlt)
            .clipShape(RoundedRectangle(cornerRadius: FlareDesign.Radius.medium, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(sticker.id)
    }
}

enum ComposerMoreKind {
    case file, video, location, card, task, schedule, poll, link, miniProgram, topic, notification, announcement
}

struct ComposerMoreItem: Identifiable {
    let id = UUID()
    let title: String
    let symbol: String
    let color: Color
    let kind: ComposerMoreKind
}

struct MoreComposerPanel: View {
    let onSelect: (ComposerMoreItem) -> Void

    private let items: [ComposerMoreItem] = [
        ComposerMoreItem(title: String(localized: "File"), symbol: "folder", color: .orange, kind: .file),
        ComposerMoreItem(title: String(localized: "Video"), symbol: "video", color: .cyan, kind: .video),
        ComposerMoreItem(title: String(localized: "Location"), symbol: "mappin.and.ellipse", color: .green, kind: .location),
        ComposerMoreItem(title: String(localized: "Contact"), symbol: "doc.text", color: .indigo, kind: .card),
        ComposerMoreItem(title: String(localized: "Task"), symbol: "checkmark.square", color: .purple, kind: .task),
        ComposerMoreItem(title: String(localized: "Schedule"), symbol: "calendar", color: .pink, kind: .schedule),
        ComposerMoreItem(title: String(localized: "Vote"), symbol: "checkmark.square.fill", color: .green, kind: .poll),
        ComposerMoreItem(title: String(localized: "Link"), symbol: "link", color: .blue, kind: .link),
        ComposerMoreItem(title: String(localized: "Mini program"), symbol: "square.grid.3x3", color: .teal, kind: .miniProgram),
        ComposerMoreItem(title: String(localized: "Topic"), symbol: "bubble.left.and.bubble.right", color: .purple, kind: .topic),
        ComposerMoreItem(title: String(localized: "Notification"), symbol: "bell", color: .orange, kind: .notification),
        ComposerMoreItem(title: String(localized: "Announcement"), symbol: "megaphone", color: .red, kind: .announcement)
    ]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: FlareDesign.Spacing.md), count: 4), spacing: FlareDesign.Spacing.lg) {
            ForEach(items) { item in
                Button {
                    onSelect(item)
                } label: {
                    VStack(spacing: FlareDesign.Spacing.sm) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(item.color)
                            .clipShape(RoundedRectangle(cornerRadius: FlareDesign.radius, style: .continuous))
                        Text(item.title)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(FlareDesign.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, FlareDesign.Spacing.lg)
        .padding(.top, FlareDesign.Spacing.lg)
        .padding(.bottom, FlareDesign.Spacing.xl)
        .background(FlareDesign.surfaceAlt)
    }
}
