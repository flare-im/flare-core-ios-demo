import FlareCoreAppleSDK
import SwiftUI

struct SearchView: View {
    @ObservedObject var viewModel: SearchViewModel

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: FlareDesign.Spacing.lg) {
                SectionHeader(
                    title: "Message Search",
                    subtitle: "Covers global and in-conversation search APIs with typed filters."
                )
                HStack(spacing: FlareDesign.Spacing.md) {
                    TextField("Keyword", text: $viewModel.draft.keyword)
                        .textFieldStyle(.roundedBorder)
                    TextField("Sender", text: $viewModel.draft.senderId)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 180)
                    Picker("Kind", selection: $viewModel.draft.kind) {
                        ForEach(MessageSearchKind.allCasesForExample, id: \.rawValue) { kind in
                            Text(kind.rawValue).tag(kind)
                        }
                    }
                    .frame(maxWidth: 160)
                }
                HStack {
                    Toggle("Scope to selected conversation", isOn: $viewModel.draft.conversationScoped)
                    Toggle("Include recalled", isOn: $viewModel.draft.includeRecalled)
                    Spacer()
                    Button {
                        Task { await viewModel.search() }
                    } label: {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(FlareDesign.Spacing.xl)
            .background(FlareDesign.surface)

            Divider()

            if viewModel.results.isEmpty {
                EmptyStateView(
                    title: "No search results",
                    message: "Enter a keyword or use empty typed filters to probe the SDK search path.",
                    symbol: "magnifyingglass"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: FlareDesign.Spacing.md) {
                        ForEach(viewModel.results, id: \.appStableId) { message in
                            VStack(alignment: .leading, spacing: FlareDesign.Spacing.xs) {
                                Text(message.conversationId)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(FlareDesign.textSecondary)
                                MessageRow(message: message)
                            }
                            .padding(.horizontal, FlareDesign.Spacing.xl)
                        }
                    }
                    .padding(.vertical, FlareDesign.Spacing.xl)
                }
            }
        }
        .background(FlareDesign.appBackground)
    }
}

private extension MessageSearchKind {
    static var allCasesForExample: [MessageSearchKind] {
        [.message, .text, .media, .image, .video, .audio, .file]
    }
}
