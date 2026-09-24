import FlareIMUI
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

                VStack(alignment: .leading, spacing: FlareDesign.Spacing.md) {
                    Text("Login Defaults")
                        .font(.headline)
                    TextField("User id", text: settings.draftBinding(\.userId))
                        .textFieldStyle(.roundedBorder)
                        .identifierInput()
                    TextField("WebSocket URL", text: settings.draftBinding(\.wsUrl))
                        .textFieldStyle(.roundedBorder)
                        .identifierInput()
                    TextField("Tenant", text: settings.draftBinding(\.tenantId))
                        .textFieldStyle(.roundedBorder)
                        .identifierInput()
                    // 网关 HTTP 基址：SDK 向它签发接入 token 并自动刷新；客户端从不持有签名密钥。
                    TextField("Gateway HTTP URL", text: settings.draftBinding(\.httpUrl))
                        .textFieldStyle(.roundedBorder)
                        .identifierInput()
                    // 应用托管：直接填业务后端签好的 token，SDK 原样使用；留空则 SDK 托管，向网关签发并自动刷新。
                    TextField("Access token (optional)", text: settings.draftBinding(\.tokenOverride))
                        .textFieldStyle(.roundedBorder)
                        .identifierInput()
                    Text("Leave empty to let the SDK request and refresh credentials from the gateway.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(FlareDesign.Spacing.lg)

                VStack(alignment: .leading, spacing: FlareDesign.Spacing.md) {
                    Text("Session")
                        .font(.headline)
                    KeyValueRows(values: [
                        ("User", settings.currentUserId ?? ""),
                        ("Connection", settings.connectionState.rawValue),
                        ("Runtime", settings.runtimeStatus.title)
                    ])
                    HStack {
                        ButtonView(label: "Refresh diagnostics", variant: .secondary) { Task { await settings.refreshDiagnostics() } }
                        ButtonView(label: "Logout", variant: .secondary) { Task { await settings.logout() } }
                        ButtonView(label: "Dispose", variant: .danger) { Task { await settings.dispose() } }
                    }

                }
                .padding(FlareDesign.Spacing.lg)

                VStack(alignment: .leading, spacing: FlareDesign.Spacing.md) {
                    Text("Media cache")
                        .font(.headline)
                    Text("Usage: \(settings.cacheStats ?? "—")")
                        .foregroundStyle(FlareDesign.textSecondary)
                    HStack {
                        ForEach([Int64(128), 256, 512], id: \.self) { mb in
                            ButtonView(label: "\(mb)MB", variant: .secondary) { Task { await settings.setCacheMaxBytes(mb * 1024 * 1024) } }
                        }
                    }
                    HStack {
                        ButtonView(label: "Refresh", variant: .secondary) { Task { await settings.refreshCacheStats() } }
                        ButtonView(label: "Clear cache", variant: .danger) { Task { await settings.clearCache() } }
                    }
                }

                .padding(FlareDesign.Spacing.lg)
                .task { await settings.refreshCacheStats() }
            }
            .padding(FlareDesign.Spacing.xl)
        }
        .background(FlareDesign.appBackground)
    }
}
