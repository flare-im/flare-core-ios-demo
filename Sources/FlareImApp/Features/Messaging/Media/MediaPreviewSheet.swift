import FlareCoreAppleSDK
import AVFoundation
import AVKit
import SwiftUI

struct MediaPreview: Identifiable {
    enum Kind {
        case image
        case video
    }

    let id = UUID()
    let kind: Kind
    let url: URL
    let title: String
}

struct MediaPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let preview: MediaPreview
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                switch preview.kind {
                case .image:
                    AsyncImage(url: preview.url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .scaleEffect(scale)
                                .offset(offset)
                                .gesture(
                                    SimultaneousGesture(
                                        MagnificationGesture()
                                            .onChanged { scale = min(max(lastScale * $0, 1), 5) }
                                            .onEnded { _ in lastScale = scale },
                                        DragGesture()
                                            .onChanged {
                                                if scale > 1 {
                                                    offset = CGSize(width: lastOffset.width + $0.translation.width,
                                                                    height: lastOffset.height + $0.translation.height)
                                                }
                                            }
                                            .onEnded { _ in
                                                lastOffset = offset
                                                if scale <= 1 { offset = .zero; lastOffset = .zero }
                                            }
                                    )
                                )
                                .onTapGesture(count: 2) {
                                    withAnimation {
                                        if scale > 1 { scale = 1; lastScale = 1; offset = .zero; lastOffset = .zero }
                                        else { scale = 2.5; lastScale = 2.5 }
                                    }
                                }
                                .padding()
                        case .failure:
                            unavailable
                        case .empty:
                            ProgressView()
                                .tint(.white)
                        @unknown default:
                            unavailable
                        }
                    }
                case .video:
                    VideoPlayer(player: AVPlayer(url: preview.url))
                        .padding()
                }
            }
            .navigationTitle(preview.title)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
    }

    private var unavailable: some View {
        VStack(spacing: FlareDesign.Spacing.md) {
            Image(systemName: "photo")
                .font(.system(size: 42, weight: .semibold))
            Text("Image preview unavailable")
                .font(.headline)
            Text(preview.url.absoluteString)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.68))
                .multilineTextAlignment(.center)
                .padding(.horizontal, FlareDesign.Spacing.xxl)
        }
        .foregroundStyle(.white)
    }
}

