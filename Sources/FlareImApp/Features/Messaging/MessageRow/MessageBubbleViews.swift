import FlareCoreAppleSDK
import AVFoundation
import AVKit
import SwiftUI

struct MessageBubble: View {
    let message: AppMessage
    let outgoing: Bool
    let deliveryState: MessageDeliveryState
    let onOpenMedia: (MediaPreview) -> Void

    private var hasStandaloneVisualContent: Bool {
        guard !message.isRecalled, message.quotePreview?.isEmpty != false else { return false }
        guard let content = message.content else { return false }
        switch content.contentType {
        case .emoji:
            if emojiAssetURL(content: content) != nil {
                return true
            }
            return content.stringValue("emoji", "key")
                .flatMap(EmojiPresentation.singleEmoji) != nil
        case .text:
            guard let rawText = content.stringValue("text", "plainText") else { return false }
            return EmojiPresentation.lonePackKey(in: rawText) != nil ||
                EmojiPresentation.singleEmoji(in: rawText) != nil
        case .sticker:
            return stickerAssetURL(content: content) != nil
        default:
            return false
        }
    }

    private var hasVisualMediaContent: Bool {
        guard !message.isRecalled, message.quotePreview?.isEmpty != false else { return false }
        guard let content = message.content else { return false }
        return content.contentType == .image || content.contentType == .imageGroup || content.contentType == .video
    }

    private var isBareAudioContent: Bool {
        guard !message.isRecalled, message.quotePreview?.isEmpty != false else { return false }
        return message.content?.contentType == .audio
    }

    private var hasMediaCaption: Bool {
        guard !message.isRecalled, message.quotePreview?.isEmpty != false else { return false }
        guard let content = message.content else { return false }
        switch content.contentType {
        case .image, .imageGroup, .video:
            return mediaCaption(content: content) != nil
        default:
            return false
        }
    }

    private var isBareVisualContent: Bool {
        hasStandaloneVisualContent || (hasVisualMediaContent && !hasMediaCaption) || isBareAudioContent
    }

    private var isCompactImageBubble: Bool {
        false
    }

    private var usesBubbleChrome: Bool {
        !isBareVisualContent
    }

    var body: some View {
        bubbleContent
            .padding(.horizontal, horizontalContentPadding)
            .padding(.vertical, verticalContentPadding)
            .padding(.trailing, deliveryContentPadding)
            .background(usesBubbleChrome ? bubbleColor : Color.clear)
            .foregroundStyle(outgoing ? FlareDesign.outgoingText : FlareDesign.textPrimary)
            .clipShape(RoundedRectangle(cornerRadius: FlareDesign.Radius.medium, style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                if showsBubbleTail {
                    OutgoingBubbleTail()
                        .fill(bubbleColor)
                        .frame(width: 10, height: 11)
                        .offset(x: 4, y: 1)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if outgoing, deliveryState != .none {
                    DeliveryStatusGlyph(state: deliveryState, lightBackground: isBareVisualContent)
                        .padding(.trailing, isBareVisualContent ? 8 : 8)
                        .padding(.bottom, isBareVisualContent ? 6 : 5)
                }
            }
            .shadow(color: outgoing && usesBubbleChrome ? FlareDesign.brand.opacity(0.22) : Color.clear, radius: isCompactImageBubble ? 10 : 8, x: 0, y: 5)
            .frame(maxWidth: maxBubbleWidth, alignment: outgoing ? .trailing : .leading)
    }

    private var bubbleContent: some View {
        VStack(alignment: .leading, spacing: FlareDesign.Spacing.sm) {
            if let quote = message.quotePreview, !quote.isEmpty {
                Text(quote)
                    .font(.caption)
                    .foregroundStyle(outgoing ? FlareDesign.outgoingText.opacity(0.78) : FlareDesign.textSecondary)
                    .padding(FlareDesign.Spacing.sm)
                    .background(outgoing ? Color.white.opacity(0.13) : Color.black.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: FlareDesign.Radius.small, style: .continuous))
            }
            content
            if !message.reactions.isEmpty {
                Text("\(message.reactions.count) reactions")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(outgoing ? FlareDesign.outgoingText.opacity(0.88) : FlareDesign.brand)
                    .padding(.horizontal, FlareDesign.Spacing.sm)
                    .padding(.vertical, FlareDesign.Spacing.xs)
                    .background(outgoing ? Color.white.opacity(0.16) : FlareDesign.brandSoft)
                    .clipShape(Capsule())
            }
        }
    }

    private var deliveryContentPadding: CGFloat {
        if outgoing && deliveryState != .none && isBareAudioContent { return 30 }
        return outgoing && deliveryState != .none && usesBubbleChrome && !isCompactImageBubble ? 32 : 0
    }

    private var horizontalContentPadding: CGFloat {
        if isBareVisualContent { return 0 }
        if isCompactImageBubble { return 7 }
        return 11
    }

    private var verticalContentPadding: CGFloat {
        if isBareVisualContent { return 0 }
        if isCompactImageBubble { return 7 }
        return 8
    }

    private var maxBubbleWidth: CGFloat {
        if hasVisualMediaContent { return 292 }
        if hasStandaloneVisualContent { return 148 }
        return 265
    }

    private var bubbleColor: Color {
        outgoing ? FlareDesign.outgoing : FlareDesign.incoming
    }

    private var showsBubbleTail: Bool {
        outgoing && usesBubbleChrome && !message.isRecalled
    }

    @ViewBuilder
    private var content: some View {
        if message.isRecalled {
            Label("Message recalled", systemImage: "arrow.uturn.backward.circle")
                .font(.subheadline)
        } else if let content = message.content {
            switch content.contentType {
            case .text:
                EmojiAwareTextMessageView(content: content)
            case .richText:
                RichTextMessageView(content: content, outgoing: outgoing)
            case .emoji:
                EmojiMessageView(content: content, outgoing: outgoing)
            case .sticker:
                StickerMessageView(content: content, outgoing: outgoing)
            case .image, .imageGroup:
                ImageMessageView(content: content, outgoing: outgoing) { preview in
                    onOpenMedia(preview)
                }
            case .video:
                VideoMessageView(content: content, outgoing: outgoing) { preview in
                    onOpenMedia(preview)
                }
            case .audio:
                AudioMessageView(content: content, outgoing: outgoing)
            case .file:
                FileMessageView(content: content, outgoing: outgoing)
            case .location:
                RichCardMessageView(title: String(localized: "Location"), detail: content.previewText, symbol: "mappin.and.ellipse", outgoing: outgoing)
            case .card, .linkCard:
                RichCardMessageView(title: content.contentType == .linkCard ? String(localized: "Link") : String(localized: "Card"), detail: content.previewText, symbol: content.contentType == .linkCard ? "link" : "rectangle.on.rectangle", outgoing: outgoing)
            case .miniProgram:
                RichCardMessageView(title: String(localized: "Mini program"), detail: content.previewText, symbol: "app", outgoing: outgoing)
            case .quote, .forward, .thread:
                AttachmentMessageView(title: content.contentType.title, detail: content.previewText, symbol: "arrowshape.turn.up.left", outgoing: outgoing)
            case .system, .notification, .announcement:
                RichCardMessageView(title: content.contentType.title, detail: content.previewText, symbol: "megaphone", outgoing: outgoing)
            case .vote, .task, .schedule:
                StructuredWorkMessageView(content: content, outgoing: outgoing)
            case .custom, .placeholder:
                AttachmentMessageView(title: content.contentType.title, detail: content.previewText, symbol: "shippingbox", outgoing: outgoing)
            }
        } else {
            Label("Unsupported message", systemImage: "questionmark.square")
                .font(.subheadline)
        }
    }

    private func emojiAssetURL(content: MessageContent) -> URL? {
        guard let key = content.stringValue("emoji", "key").flatMap(EmojiPresentation.normalizedPackKey) else {
            return nil
        }
        return EmojiPresentation.emojiURL(for: key)
    }

    private func stickerAssetURL(content: MessageContent) -> URL? {
        guard let stickerId = content.stringValue("stickerId", "id") else { return nil }
        let packageId = content.stringValue("packageId", "package_id") ?? "gifs"
        return EmojiPresentation.stickerURL(packageId: packageId, stickerId: stickerId)
    }

    private func mediaCaption(content: MessageContent) -> String? {
        guard let caption = content.stringValue("description", "title")?.trimmingCharacters(in: .whitespacesAndNewlines),
              !caption.isEmpty else {
            return nil
        }
        if caption.lowercased().hasPrefix("local-image-") {
            return nil
        }
        return caption
    }
}

private struct OutgoingBubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + 1))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control: CGPoint(x: rect.maxX - 1, y: rect.midY)
        )
        path.addLine(to: CGPoint(x: rect.minX + 1, y: rect.maxY - 1))
        path.closeSubpath()
        return path
    }
}

private struct EmojiAwareTextMessageView: View {
    let content: MessageContent

    var body: some View {
        if let rawText = content.stringValue("text", "plainText"),
           let key = EmojiPresentation.lonePackKey(in: rawText) {
            FlareAssetImageView(
                url: EmojiPresentation.emojiURL(for: key),
                fallbackSystemImage: "face.smiling",
                accessibilityLabel: key,
                size: 88,
                travel: 5,
                rotation: 3.6,
                isAnimated: true
            )
                .frame(width: 108, height: 108)
        } else if let rawText = content.stringValue("text", "plainText"),
                  let emoji = EmojiPresentation.singleEmoji(in: rawText) {
            UnicodeEmojiMessageView(value: emoji)
        } else {
            Text(content.previewText)
                .font(.body)
        }
    }
}

private struct RichTextMessageView: View {
    let content: MessageContent
    let outgoing: Bool

    var body: some View {
        RichMarkdownView(markdown: markdown, outgoing: outgoing, compact: true)
    }

    private var markdown: String {
        content.stringValue("markdown", "docMarkdown", "body") ??
            content.stringValue("plainText", "searchText", "title") ??
            content.previewText
    }
}

private struct StickerMessageView: View {
    let content: MessageContent
    let outgoing: Bool

    var body: some View {
        VStack(spacing: FlareDesign.Spacing.sm) {
            if let assetURL {
                FlareAssetImageView(
                    url: assetURL,
                    fallbackSystemImage: "rectangle.stack.fill",
                    accessibilityLabel: stickerTitle,
                    size: 112,
                    travel: 5,
                    rotation: 3.4,
                    isAnimated: true
                )
            } else if let url = content.mediaSourceURL {
                stickerImage(url: url)
            } else {
                Image(systemName: "face.smiling")
                    .font(.system(size: 40, weight: .semibold))
            }
            if assetURL == nil {
                Text(stickerTitle)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
        }
        .frame(width: assetURL == nil ? 126 : 132, height: assetURL == nil ? 116 : 132)
        .foregroundStyle(outgoing ? FlareDesign.outgoingText : FlareDesign.brand)
    }

    private var stickerTitle: String {
        content.stringValue("stickerId", "id", "name", "title") ?? PreviewCopy.sticker
    }

    private var assetURL: URL? {
        guard let stickerId = content.stringValue("stickerId", "id") else { return nil }
        let packageId = content.stringValue("packageId", "package_id") ?? "gifs"
        return EmojiPresentation.stickerURL(packageId: packageId, stickerId: stickerId)
    }

    @ViewBuilder
    private func stickerImage(url: URL) -> some View {
        if url.isFileURL {
            localImage(url: url)
        } else {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                case .failure, .empty:
                    Image(systemName: "face.smiling")
                        .font(.system(size: 40, weight: .semibold))
                @unknown default:
                    Image(systemName: "face.smiling")
                        .font(.system(size: 40, weight: .semibold))
                }
            }
        }
    }

    @ViewBuilder
    private func localImage(url: URL) -> some View {
        if let image = Image(localFileURL: url) {
            image
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "face.smiling")
                .font(.system(size: 40, weight: .semibold))
        }
    }
}

private struct EmojiMessageView: View {
    let content: MessageContent
    let outgoing: Bool

    var body: some View {
        if let key = content.stringValue("emoji", "key").flatMap(EmojiPresentation.normalizedPackKey) {
            FlareAssetImageView(
                url: EmojiPresentation.emojiURL(for: key),
                fallbackSystemImage: "face.smiling",
                accessibilityLabel: key,
                size: 88,
                travel: 5,
                rotation: 3.6,
                isAnimated: true
            )
                .frame(width: 108, height: 108)
        } else if let emoji = content.stringValue("emoji", "key").flatMap(EmojiPresentation.singleEmoji) ??
                    EmojiPresentation.singleEmoji(in: content.previewText) {
            UnicodeEmojiMessageView(value: emoji)
        } else {
            Text(content.previewText)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(fallbackColor)
                .multilineTextAlignment(.center)
        }
    }

    private var fallbackColor: Color {
        outgoing ? FlareDesign.outgoingText.opacity(0.86) : FlareDesign.textSecondary
    }
}

private struct UnicodeEmojiMessageView: View {
    let value: String

    var body: some View {
        Text(value)
            .font(.system(size: 56))
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .frame(width: 132, height: 132, alignment: .center)
            .accessibilityLabel(value)
    }
}

private struct AttachmentMessageView: View {
    let title: String
    let detail: String
    let symbol: String
    let outgoing: Bool

    var body: some View {
        HStack(alignment: .top, spacing: FlareDesign.Spacing.md) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .frame(width: 30, height: 30)
                .foregroundStyle(outgoing ? FlareDesign.outgoingText : FlareDesign.brand)
            VStack(alignment: .leading, spacing: FlareDesign.Spacing.xs) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(outgoing ? FlareDesign.outgoingText.opacity(0.76) : FlareDesign.textSecondary)
                    .lineLimit(3)
            }
        }
    }
}

private struct DeliveryStatusGlyph: View {
    let state: MessageDeliveryState
    var lightBackground = false

    var body: some View {
        Group {
            switch state {
            case .none:
                EmptyView()
            case .sending:
                ProgressView()
                    .controlSize(.mini)
                    .tint(Color.white.opacity(0.85))
            case .failed:
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 10, weight: .bold))
            case .delivered:
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
            case .read:
                HStack(spacing: -2) {
                    Image(systemName: "checkmark")
                    Image(systemName: "checkmark")
                }
                .font(.system(size: 10.5, weight: .bold))
            }
        }
        .foregroundStyle(foregroundColor)
        .shadow(color: lightBackground ? Color.black.opacity(0.26) : Color.clear, radius: 2, x: 0, y: 1)
        .accessibilityLabel(accessibilityLabel)
    }

    private var foregroundColor: Color {
        if lightBackground {
            switch state {
            case .failed: return FlareDesign.danger
            case .sending, .delivered, .read, .none: return Color.white.opacity(0.96)
            }
        }
        return Color.white.opacity(state == .read ? 0.96 : 0.78)
    }

    private var accessibilityLabel: String {
        switch state {
        case .none: return ""
        case .sending: return String(localized: "Sending")
        case .failed: return String(localized: "Failed")
        case .delivered: return String(localized: "Delivered")
        case .read: return String(localized: "Read")
        }
    }
}
