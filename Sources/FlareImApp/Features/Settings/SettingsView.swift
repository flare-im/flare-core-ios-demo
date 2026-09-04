import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FlareDesign.Spacing.xl) {
                SectionHeader(title: "Settings", subtitle: "Runtime controls, theme, diagnostics, and session cleanup.")

                VStack(alignment: .leading, spacing: FlareDesign.Spacing.md) {
                    Text("Appearance")
                        .font(.headline)
                    Picker("Theme", selection: settings.themeChoice) {
                        ForEach(ThemeChoice.allCases) { choice in
                            Text(choice.title).tag(choice)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(FlareDesign.Spacing.lg)
                .flarePanel()

                VStack(alignment: .leading, spacing: FlareDesign.Spacing.md) {
                    Text("Login Defaults")
                        .font(.headline)
                    TextField("User id", text: settings.draftBinding(\.userId))
                        .textFieldStyle(.roundedBorder)
                    TextField("WebSocket URL", text: settings.draftBinding(\.wsUrl))
                        .textFieldStyle(.roundedBorder)
                    TextField("Tenant", text: settings.draftBinding(\.tenantId))
                        .textFieldStyle(.roundedBorder)
                    // 网关 HTTP 基址：SDK 向它签发接入 token 并自动刷新；客户端从不持有签名密钥。
                    TextField("Gateway HTTP URL", text: settings.draftBinding(\.httpUrl))
                        .textFieldStyle(.roundedBorder)
                    // 应用托管：直接填业务后端签好的 token，SDK 原样使用；留空则 SDK 托管，向网关签发并自动刷新。
                    TextField("Access token (optional)", text: settings.draftBinding(\.tokenOverride))
                        .textFieldStyle(.roundedBorder)
                        // 不加 .textInputAutocapitalization：这个包同时编 macOS，
                        // 那个修饰符只在 iOS 可用。
                        .autocorrectionDisabled()
                    Text("Leave empty to sign locally with the token secret above.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(FlareDesign.Spacing.lg)
                .flarePanel()

                VStack(alignment: .leading, spacing: FlareDesign.Spacing.md) {
                    Text("Session")
                        .font(.headline)
                    KeyValueRows(values: [
                        ("User", settings.currentUserId ?? ""),
                        ("Connection", settings.connectionState.rawValue),
                        ("Runtime", settings.runtimeStatus.title)
                    ])
                    HStack {
                        Button("Refresh diagnostics") { Task { await settings.refreshDiagnostics() } }
                        Button("Logout") { Task { await settings.logout() } }
                        Button("Dispose", role: .destructive) { Task { await settings.dispose() } }
                    }
                    .buttonStyle(.bordered)
                }
                .padding(FlareDesign.Spacing.lg)
                .flarePanel()

                VStack(alignment: .leading, spacing: FlareDesign.Spacing.md) {
                    Text("Media cache")
                        .font(.headline)
                    Text("Usage: \(settings.cacheStats ?? "—")")
                        .foregroundStyle(FlareDesign.textSecondary)
                    HStack {
                        ForEach([Int64(128), 256, 512], id: \.self) { mb in
                            Button("\(mb)MB") { Task { await settings.setCacheMaxBytes(mb * 1024 * 1024) } }
                        }
                    }
                    HStack {
                        Button("Refresh") { Task { await settings.refreshCacheStats() } }
                        Button("Clear cache", role: .destructive) { Task { await settings.clearCache() } }
                    }
                }
                .buttonStyle(.bordered)
                .padding(FlareDesign.Spacing.lg)
                .flarePanel()
                .task { await settings.refreshCacheStats() }
            }
            .padding(FlareDesign.Spacing.xl)
        }
        .background(FlareDesign.appBackground)
    }
}
