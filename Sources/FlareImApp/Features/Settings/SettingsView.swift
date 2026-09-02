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
                    HStack {
                        TextField("Tenant", text: settings.draftBinding(\.tenantId))
                            .textFieldStyle(.roundedBorder)
                        TextField("Issuer", text: settings.draftBinding(\.tokenIssuer))
                            .textFieldStyle(.roundedBorder)
                        TextField("TTL", text: settings.draftBinding(\.tokenTtlSeconds))
                            .textFieldStyle(.roundedBorder)
                    }
                    SecureField("Token secret", text: settings.draftBinding(\.tokenSecret))
                        .textFieldStyle(.roundedBorder)
                    // 直接填服务端签好的 token 就不需要本地持有签名密钥。
                    // resolveToken 里 tokenOverride 优先于本地自签，但一直没有界面入口，
                    // 于是这个 app 实际上只能连"自己握有密钥"的服务器 ——
                    // 而把签名密钥放进客户端等于让任何拿到安装包的人伪造任意用户身份。
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
