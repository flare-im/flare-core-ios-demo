import FlareCoreAppleSDK
import AVFoundation
import AVKit
import SwiftUI

struct ImageMessageView: View {
    @EnvironmentObject private var messaging: MessagingViewModel
    let content: MessageContent
    let outgoing: Bool
    let onOpen: (MediaPreview) -> Void
    @State private var resolvedMediaURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: FlareDesign.Spacing.xs) {
            Group {
                if let url = displayURL {
                    mediaImage(url: url)
                } else {
                    imagePlaceholder
                }
            }
            .frame(width: imageDisplaySize.width, height: imageDisplaySize.height)
            .background(imageBackground)
            .clipShape(RoundedRectangle(cornerRadius: imageCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: imageCornerRadius, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 0.5)
            }
            .shadow(color: Color.black.opacity(outgoing ? 0.12 : 0.08), radius: outgoing ? 10 : 8, x: 0, y: 4)
            .contentShape(RoundedRectangle(cornerRadius: imageCornerRadius, style: .continuous))
            .onTapGesture {
                guard let url = displayURL else { return }
                onOpen(MediaPreview(
                    kind: .image,
                    url: url,
                    title: content.stringValue("description", "title") ?? String(localized: "Image")
                ))
            }

            if let caption = imageCaption {
                Text(caption)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(outgoing ? Color.white.opacity(0.90) : FlareDesign.textSecondary)
                    .lineLimit(2)
                    .padding(.horizontal, 2)
            }
        }
        .frame(width: imageDisplaySize.width, alignment: .leading)
        .task(id: content.mediaResolveKey) {
            resolvedMediaURL = await messaging.resolveMediaDisplayURL(
                fileId: content.mediaFileId,
                directURL: content.mediaSourceURL
            )
        }
    }

    private var displayURL: URL? {
        resolvedMediaURL ?? content.mediaSourceURL
    }

    private var imageCaption: String? {
        guard let caption = content.stringValue("description", "title")?.trimmingCharacters(in: .whitespacesAndNewlines),
              !caption.isEmpty else {
            return nil
        }
        if caption.lowercased().hasPrefix("local-image-") {
            return nil
        }
        return caption
    }

    private var imageDisplaySize: CGSize {
        let fallback = CGSize(width: 244, height: 164)
        guard let pixelSize = content.imagePixelSize else { return fallback }

        let sourceWidth = max(1, pixelSize.width)
        let sourceHeight = max(1, pixelSize.height)
        let maxWidth: CGFloat = 268
        let maxHeight: CGFloat = 318
        let minWidth: CGFloat = 148
        let minHeight: CGFloat = 112

        let shrink = min(maxWidth / sourceWidth, maxHeight / sourceHeight, 1)
        var width = sourceWidth * shrink
        var height = sourceHeight * shrink

        if width < minWidth {
            let grow = min(minWidth / width, maxHeight / height)
            width *= grow
            height *= grow
        }
        if height < minHeight {
            let grow = min(minHeight / height, maxWidth / width)
            width *= grow
            height *= grow
        }

        return CGSize(width: floor(width), height: floor(height))
    }

    private var imageCornerRadius: CGFloat {
        outgoing ? FlareDesign.Radius.medium : FlareDesign.Radius.large
    }

    private var imageBackground: Color {
        FlareDesign.surface
    }

    private var imagePlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: outgoing
                    ? [FlareDesign.brand.opacity(0.15), FlareDesign.brand.opacity(0.07)]
                    : [FlareDesign.brandSoft, Color.white.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "photo")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(FlareDesign.brand)
        }
    }

    @ViewBuilder
    private func mediaImage(url: URL) -> some View {
        if url.isFileURL {
            localImage(url: url)
        } else {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                case .failure:
                    imagePlaceholder
                case .empty:
                    imagePlaceholder
                        .overlay {
                            ProgressView()
                                .tint(outgoing ? .white : FlareDesign.brand)
                        }
                @unknown default:
                    imagePlaceholder
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
            imagePlaceholder
        }
    }
}

struct VideoMessageView: View {
    @EnvironmentObject private var messaging: MessagingViewModel
    let content: MessageContent
    let outgoing: Bool
    let onOpen: (MediaPreview) -> Void
    @State private var resolvedMediaURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: FlareDesign.Spacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: FlareDesign.Radius.medium, style: .continuous)
                    .fill(Color.black.opacity(outgoing ? 0.22 : 0.82))
                if let url = displayURL {
                    VideoPlayer(player: AVPlayer(url: url))
                        .clipShape(RoundedRectangle(cornerRadius: FlareDesign.Radius.medium, style: .continuous))
                } else {
                    Image(systemName: "video")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.86))
                }
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.90))
                    .shadow(color: .black.opacity(0.22), radius: 8, x: 0, y: 3)
                    .allowsHitTesting(false)
            }
            .frame(width: 214, height: 136)
            .contentShape(RoundedRectangle(cornerRadius: FlareDesign.Radius.medium, style: .continuous))
            .onTapGesture {
                guard let url = displayURL else { return }
                onOpen(MediaPreview(kind: .video, url: url, title: content.stringValue("description", "title") ?? String(localized: "Video")))
            }

            if let caption = videoCaption {
                mediaCaption(icon: "video.fill", caption: caption)
            }
        }
        .task(id: content.mediaResolveKey) {
            resolvedMediaURL = await messaging.resolveMediaDisplayURL(
                fileId: content.mediaFileId,
                directURL: content.mediaSourceURL
            )
        }
    }

    private var displayURL: URL? {
        resolvedMediaURL ?? content.mediaSourceURL
    }

    private var videoCaption: String? {
        guard let caption = content.stringValue("description", "title")?.trimmingCharacters(in: .whitespacesAndNewlines),
              !caption.isEmpty else {
            return nil
        }
        return caption
    }

    @ViewBuilder
    private func mediaCaption(icon: String, caption: String) -> some View {
        HStack(spacing: FlareDesign.Spacing.sm) {
            Image(systemName: icon)
                .font(.caption2.weight(.bold))
            Text(caption)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            if let duration = content.mediaDurationText {
                Text(duration)
                    .font(.caption2)
            }
            if let size = content.mediaByteSize {
                Text(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
                    .font(.caption2)
            }
        }
        .foregroundStyle(outgoing ? Color.white.opacity(0.80) : FlareDesign.textSecondary)
    }
}

struct AudioMessageView: View {
    @EnvironmentObject private var messaging: MessagingViewModel
    let content: MessageContent
    let outgoing: Bool
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var playbackSeconds = 0
    @State private var resolvedMediaURL: URL?
    @State private var endObserver: NSObjectProtocol?
    @State private var failObserver: NSObjectProtocol?
    @State private var timeObserver: Any?

    var body: some View {
        Button {
            togglePlayback()
        } label: {
            HStack(spacing: FlareDesign.Spacing.sm) {
                if outgoing {
                    progressLabel
                    Spacer(minLength: FlareDesign.Spacing.sm)
                    VoiceWaveformBars(active: isPlaying, outgoing: outgoing)
                    voiceIcon
                } else {
                    voiceIcon
                    VoiceWaveformBars(active: isPlaying, outgoing: outgoing)
                    Spacer(minLength: FlareDesign.Spacing.sm)
                    progressLabel
                }
            }
            .padding(.horizontal, FlareDesign.Spacing.sm)
            .frame(width: voiceWidth, height: 38)
            .background(audioPillBackground)
            .overlay {
                Capsule()
                    .stroke(outgoing ? Color.clear : Color.black.opacity(0.04), lineWidth: 0.5)
            }
            .clipShape(Capsule())
            .shadow(color: audioPillShadow, radius: outgoing ? 8 : 5, x: 0, y: 3)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(displayURL == nil)
        .opacity(displayURL == nil ? 0.55 : 1)
        .accessibilityLabel(Text("Voice message"))
        .task(id: content.mediaResolveKey) {
            resolvedMediaURL = await messaging.resolveMediaDisplayURL(
                fileId: content.mediaFileId,
                directURL: content.mediaSourceURL
            )
        }
        .onDisappear {
            stopPlayback(resetProgress: true, deactivateSession: true)
        }
    }

    private var displayURL: URL? {
        resolvedMediaURL ?? content.mediaSourceURL
    }

    private var voiceIcon: some View {
        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(outgoing ? Color.white.opacity(0.96) : FlareDesign.brand)
            .frame(width: 28, height: 28)
            .background(outgoing ? Color.white.opacity(0.18) : Color.white.opacity(0.92))
            .clipShape(Circle())
    }

    private var progressLabel: some View {
        Text(audioTimeText)
            .font(.callout.monospacedDigit().weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(outgoing ? Color.white.opacity(0.90) : FlareDesign.textSecondary)
    }

    private var audioPillBackground: some ShapeStyle {
        outgoing ? FlareDesign.outgoing : FlareDesign.brandSoft
    }

    private var audioPillShadow: Color {
        outgoing ? FlareDesign.brand.opacity(0.18) : Color.black.opacity(0.05)
    }

    private var audioTimeText: String {
        if isPlaying || playbackSeconds > 0 {
            return "\(min(playbackSeconds, durationSeconds))\" / \(durationSeconds)\""
        }
        return "\(durationSeconds)\""
    }

    private var durationSeconds: Int {
        guard let durationMs = content.mediaDurationMs, durationMs > 0 else { return 1 }
        return max(1, Int((Double(durationMs) / 1000).rounded()))
    }

    private var voiceWidth: CGFloat {
        let clamped = min(max(durationSeconds, 1), 65)
        return CGFloat(min(238, 112 + clamped * 2))
    }

    private func togglePlayback() {
        guard let url = displayURL, let playableURL = playableAudioURL(from: url) else { return }
        if isPlaying {
            pausePlayback()
            return
        }
        if let player {
            do {
                try PlatformAudioSession.activateForPlayback()
                player.play()
                isPlaying = true
            } catch {
                stopPlayback(resetProgress: false, deactivateSession: true)
            }
            return
        }
        do {
            try PlatformAudioSession.activateForPlayback()
        } catch {
            return
        }
        stopPlayback(resetProgress: true, deactivateSession: false)
        let next = AVPlayer(url: playableURL)
        next.actionAtItemEnd = .pause
        player = next
        installPlaybackObservers(for: next)
        next.play()
        isPlaying = true
    }

    private func pausePlayback() {
        player?.pause()
        isPlaying = false
        PlatformAudioSession.deactivate()
    }

    private func finishPlayback() {
        stopPlayback(resetProgress: true, deactivateSession: true)
    }

    private func stopPlayback(resetProgress: Bool, deactivateSession: Bool) {
        if let observer = endObserver {
            NotificationCenter.default.removeObserver(observer)
            endObserver = nil
        }
        if let observer = failObserver {
            NotificationCenter.default.removeObserver(observer)
            failObserver = nil
        }
        if let token = timeObserver, let player {
            player.removeTimeObserver(token)
            timeObserver = nil
        }
        player?.pause()
        player = nil
        isPlaying = false
        if resetProgress {
            playbackSeconds = 0
        }
        if deactivateSession {
            PlatformAudioSession.deactivate()
        }
    }

    private func installPlaybackObservers(for player: AVPlayer) {
        guard let item = player.currentItem else { return }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            finishPlayback()
        }
        failObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            stopPlayback(resetProgress: false, deactivateSession: true)
        }
        let interval = CMTime(seconds: 0.2, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak player] time in
            playbackSeconds = max(0, Int(time.seconds.rounded(.down)))
            guard let player else { return }
            let duration = player.currentItem?.duration.seconds ?? Double(durationSeconds)
            if duration.isFinite, duration > 0, time.seconds >= max(0, duration - 0.05) {
                finishPlayback()
            }
        }
    }

    private func playableAudioURL(from url: URL) -> URL? {
        guard url.scheme?.lowercased() == "data" else { return url }
        guard let data = Self.decodeDataURL(url.absoluteString) else { return nil }
        let ext = Self.audioFileExtension(from: url.absoluteString)
        let key = String(url.absoluteString.hashValue).replacingOccurrences(of: "-", with: "m")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("flare-voice-cache", isDirectory: true)
        let fileURL = directory.appendingPathComponent("voice-\(key).\(ext)")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                try data.write(to: fileURL, options: [.atomic])
            }
            return fileURL
        } catch {
            return nil
        }
    }

    private static func decodeDataURL(_ raw: String) -> Data? {
        guard raw.hasPrefix("data:"), let comma = raw.firstIndex(of: ",") else { return nil }
        let header = raw[..<comma].lowercased()
        let body = String(raw[raw.index(after: comma)...])
        if header.contains(";base64") {
            return Data(base64Encoded: body)
        }
        return body.removingPercentEncoding?.data(using: .utf8)
    }

    private static func audioFileExtension(from raw: String) -> String {
        let lowered = raw.lowercased()
        if lowered.hasPrefix("data:audio/mp4") || lowered.hasPrefix("data:audio/m4a") { return "m4a" }
        if lowered.hasPrefix("data:audio/mpeg") || lowered.hasPrefix("data:audio/mp3") { return "mp3" }
        if lowered.hasPrefix("data:audio/ogg") { return "ogg" }
        if lowered.hasPrefix("data:audio/wav") { return "wav" }
        return "webm"
    }
}

private struct VoiceWaveformBars: View {
    let active: Bool
    let outgoing: Bool

    private let heights: [CGFloat] = [8, 13, 18, 12, 16]

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(Array(heights.enumerated()), id: \.offset) { index, height in
                Capsule(style: .continuous)
                    .fill(barColor(index: index))
                    .frame(width: 2.6, height: height)
                    .opacity(active ? 1 : 0.72)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: active)
    }

    private func barColor(index: Int) -> Color {
        if outgoing {
            return Color.white.opacity(active || index.isMultiple(of: 2) ? 0.92 : 0.62)
        }
        return FlareDesign.brand.opacity(active || index.isMultiple(of: 2) ? 0.82 : 0.46)
    }
}

struct FileMessageView: View {
    let content: MessageContent
    let outgoing: Bool

    var body: some View {
        HStack(spacing: FlareDesign.Spacing.md) {
            Image(systemName: "doc.fill")
                .font(.system(size: 23, weight: .semibold))
                .foregroundStyle(outgoing ? FlareDesign.brand : .white)
                .frame(width: 42, height: 42)
                .background(outgoing ? Color.white.opacity(0.88) : FlareDesign.brand)
                .clipShape(RoundedRectangle(cornerRadius: FlareDesign.Radius.medium, style: .continuous))

            VStack(alignment: .leading, spacing: FlareDesign.Spacing.xs) {
                Text(content.fileDisplayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                HStack(spacing: FlareDesign.Spacing.sm) {
                    if let mimeType = content.mediaMimeType {
                        Text(mimeType)
                    }
                    if let size = content.mediaByteSize {
                        Text(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
                    }
                }
                .font(.caption2)
                .foregroundStyle(outgoing ? Color.white.opacity(0.70) : FlareDesign.textTertiary)
                .lineLimit(1)
            }
        }
        .frame(minWidth: 190, alignment: .leading)
    }
}
