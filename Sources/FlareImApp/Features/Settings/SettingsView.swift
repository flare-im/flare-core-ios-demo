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
