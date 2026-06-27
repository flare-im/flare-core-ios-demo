import SwiftUI

struct RootWorkbenchView: View {
    @EnvironmentObject private var store: FlareAppStore
    @EnvironmentObject private var messaging: MessagingViewModel
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        ZStack {
            FlareDesign.appBackground.ignoresSafeArea()
            if store.isLoggedIn {
                WorkbenchView()
            } else {
                LoginView()
            }
        }
        .preferredColorScheme(colorScheme)
        .loadingOverlay(environment.isBusy)
    }

    private var colorScheme: ColorScheme? {
        switch environment.themeChoice {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

private struct WorkbenchView: View {
    @EnvironmentObject private var search: SearchViewModel
    @EnvironmentObject private var messaging: MessagingViewModel
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var mobileChatOpen = false

    var body: some View {
        if horizontalSizeClass == .compact {
            MobileWorkbenchView(chatOpen: $mobileChatOpen)
        } else {
            NavigationSplitView {
                SidebarView()
                    .navigationSplitViewColumnWidth(min: 280, ideal: FlareDesign.sidebarWidth, max: 420)
            } content: {
                content
            } detail: {
                if environment.detailsOpen, let conversation = messaging.selectedConversation, environment.section == .conversations {
                    ConversationDetailsPanel(conversation: conversation)
                        .navigationSplitViewColumnWidth(min: 280, ideal: FlareDesign.detailWidth, max: 420)
                } else {
                    EmptyStateView(
                        title: "Details closed",
                        message: "Open a conversation and tap the info button to inspect SDK state, presence, and actions.",
                        symbol: "sidebar.trailing"
                    )
                }
            }
            .navigationSplitViewStyle(.balanced)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch environment.section {
        case .conversations:
            if let conversation = messaging.selectedConversation {
                ChatView(conversation: conversation)
            } else {
                EmptyStateView(
                    title: "Choose a conversation",
                    message: "Your timeline, composer, message actions, and sync state will appear here.",
                    symbol: "bubble.left.and.bubble.right",
                    actionTitle: "Refresh",
                    action: { Task { await messaging.refreshConversations() } }
                )
            }
        case .search:
            SearchView(viewModel: search)
        case .sdkLab:
            SdkLabView()
        case .settings:
            SettingsView()
        }
    }
}

private struct MobileWorkbenchView: View {
    @EnvironmentObject private var search: SearchViewModel
    @EnvironmentObject private var messaging: MessagingViewModel
    @EnvironmentObject private var environment: AppEnvironment
    @Binding var chatOpen: Bool

    var body: some View {
        ZStack {
            FlareDesign.appBackground.ignoresSafeArea()
            if chatOpen, let conversation = messaging.selectedConversation, environment.section == .conversations {
                ChatView(
                    conversation: conversation,
                    showsBackButton: true,
                    onBack: { chatOpen = false }
                )
            } else {
                mobileContent
            }
        }
        .onChange(of: environment.section) { section in
            if section != .conversations {
                chatOpen = false
            }
        }
        .task {
            if messaging.allConversations.isEmpty {
                await messaging.refreshConversations()
            }
        }
    }

    @ViewBuilder
    private var mobileContent: some View {
        switch environment.section {
        case .conversations:
            ConversationListView { conversation in
                chatOpen = true
                Task { await messaging.openConversation(conversation.conversationId) }
            }
        case .search:
            MobileSectionContainer(title: String(localized: "Search messages"), onBack: { environment.section = .conversations }) {
                SearchView(viewModel: search)
            }
        case .sdkLab:
            MobileSectionContainer(title: String(localized: "SDK Status"), onBack: { environment.section = .conversations }) {
                SdkLabView()
            }
        case .settings:
            MobileSectionContainer(title: String(localized: "Settings"), onBack: { environment.section = .conversations }) {
                SettingsView()
            }
        }
    }
}

private struct MobileSectionContainer<Content: View>: View {
    let title: String
    let onBack: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: FlareDesign.Spacing.md) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(FlareDesign.textPrimary)
                Spacer()
            }
            .padding(.horizontal, FlareDesign.Spacing.lg)
            .padding(.vertical, FlareDesign.Spacing.md)
            .background(FlareDesign.surface)
            Divider()
            content
        }
        .background(FlareDesign.appBackground)
    }
}

private struct SidebarView: View {
    @EnvironmentObject private var messaging: MessagingViewModel
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: FlareDesign.Spacing.lg) {
                HStack(spacing: FlareDesign.Spacing.md) {
                    appMark
                    VStack(alignment: .leading, spacing: FlareDesign.Spacing.xxs) {
                        Text("Flare IM")
                            .font(.headline.weight(.bold))
                        Text(messaging.currentUserId ?? "Secure messaging workspace")
                            .font(.caption)
                            .foregroundStyle(FlareDesign.textSecondary)
                    }
                    Spacer()
                }

                StatusBanner(status: messaging.runtimeStatus, error: messaging.lastError)

                HStack(spacing: FlareDesign.Spacing.sm) {
                    ProductMetricTile(title: "Chats", value: "\(messaging.allConversations.count)", symbol: "bubble.left.and.bubble.right", tone: .info)
                    ProductMetricTile(title: "Unread", value: "\(unreadCount)", symbol: "mail.badge", tone: unreadCount > 0 ? .danger : .neutral)
                }

                if !messaging.failedMessageKeys.isEmpty {
                    StatusPill(
                        text: "\(messaging.failedMessageKeys.count) failed send",
                        symbol: "exclamationmark.circle.fill",
                        tone: .danger
                    )
                }

                VStack(spacing: FlareDesign.Spacing.sm) {
                    ForEach(AppSection.allCases) { section in
                        Button {
                            environment.section = section
                        } label: {
                            HStack(spacing: FlareDesign.Spacing.md) {
                                Image(systemName: section.symbol)
                                    .frame(width: 22, height: 22)
                                Text(section.title)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                            }
                            .padding(.horizontal, FlareDesign.Spacing.md)
                            .padding(.vertical, FlareDesign.Spacing.sm)
                            .foregroundStyle(environment.section == section ? FlareDesign.brand : FlareDesign.textSecondary)
                            .background(environment.section == section ? FlareDesign.brandSoft : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: FlareDesign.radius, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .help(section.title)
                    }
                }
            }
            .padding(FlareDesign.Spacing.lg)

            Divider()

            ConversationListView()
        }
        .background(FlareDesign.surface)
        .task {
            if messaging.allConversations.isEmpty {
                await messaging.refreshConversations()
            }
        }
    }

    private var appMark: some View {
        ZStack {
            RoundedRectangle(cornerRadius: FlareDesign.Radius.medium, style: .continuous)
                .fill(FlareDesign.brand)
            Image(systemName: "message.badge.waveform.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: 42, height: 42)
    }

    private var unreadCount: UInt32 {
        messaging.allConversations.reduce(0) { $0 + $1.unreadCount }
    }
}
