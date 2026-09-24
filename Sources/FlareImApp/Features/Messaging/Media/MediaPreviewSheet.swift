import FlareCoreAppleSDK
import FlareIMUI
import AVFoundation
import AVKit
import SwiftUI

struct MediaPreview: Identifiable {
    enum Kind {
        case image
        case video
        case audio
    }

    let id = UUID()
    let kind: Kind
    let url: URL
    let title: String
}

struct MediaPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let preview: MediaPreview
    @State private var player: AVPlayer?

    init(preview: MediaPreview) {
        self.preview = preview
        _player = State(initialValue: preview.kind == .image ? nil : AVPlayer(url: preview.url))
    }

    var body: some View {
        switch preview.kind {
        case .image:
            ImagePreviewView(
                show: true,
                imageSrc: preview.url.absoluteString,
                alt: preview.title,
                onClose: { dismiss() }
            )
        case .video, .audio:
            VideoPlayerView(
                show: true,
                videoSrc: preview.url.absoluteString,
                title: preview.title,
                player: AnyView(VideoPlayer(player: player)),
                onClose: { player?.pause(); dismiss() }
            )
            .onDisappear { player?.pause() }
        }
    }
}
