import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var auth: AuthViewModel

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    brandHeader(height: min(max(proxy.size.height * 0.30, 252), 320))
                    form
                        .frame(maxWidth: 430)
                        .frame(maxWidth: .infinity)
                }
                .frame(minHeight: proxy.size.height, alignment: .top)
            }
            .background(Color.white)
            .scrollDismissesKeyboard(.interactively)
            .ignoresSafeArea(edges: .top)
            .loadingOverlay(auth.isBusy)
        }
    }

    private func brandHeader(height: CGFloat) -> some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.39, green: 0.10, blue: 0.76), FlareDesign.brand, Color(red: 0.39, green: 0.40, blue: 0.94)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            LoginGridBackground()

            VStack(spacing: FlareDesign.Spacing.lg) {
                ZStack {
                    RoundedRectangle(cornerRadius: FlareDesign.Radius.xl, style: .continuous)
                        .fill(.white)
                    Image(systemName: "bubble.left")
                        .font(.system(size: 33, weight: .medium))
                        .foregroundStyle(FlareDesign.brand)
                }
                .frame(width: 64, height: 64)
                .shadow(color: Color.black.opacity(0.08), radius: 16, y: 10)

                VStack(spacing: FlareDesign.Spacing.xs) {
                    Text("flare IM")
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundStyle(.white)
                    Text("Secure, fast instant messaging")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.white.opacity(0.88))
                }
                .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, minHeight: height)
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: FlareDesign.Spacing.sm) {
                Text("Welcome back")
                    .font(FlareDesign.Typography.title)
                    .foregroundStyle(FlareDesign.textPrimary)
                Text("Enter your user ID to sign in")
                    .font(.system(size: 14))
                    .foregroundStyle(FlareDesign.textSecondary)
            }
            .padding(.bottom, 28)

            LoginInputField(
                title: String(localized: "User ID"),
                placeholder: String(localized: "Enter user ID"),
                systemImage: "person",
                text: auth.draftBinding(\.userId)
            )
            .onChange(of: auth.loginDraft.userId) { _ in
                auth.clearValidation()
            }

            HStack(spacing: FlareDesign.Spacing.xs) {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundStyle(FlareDesign.brand)
                Text("Your user ID is assigned by the system and shown in account settings")
                    .font(.caption)
                    .foregroundStyle(FlareDesign.textTertiary)
            }
            .padding(.top, FlareDesign.Spacing.sm)
            .padding(.bottom, auth.validationMessage == nil ? 22 : 8)

            if let validationMessage = auth.validationMessage {
                HStack(spacing: FlareDesign.Spacing.sm) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.caption)
                    Text(validationMessage)
                        .font(.caption)
                }
                .foregroundStyle(FlareDesign.danger)
                .padding(.bottom, FlareDesign.Spacing.xl)
            }

            serverConfigSection

            if let error = auth.lastError {
                LoginErrorBanner(message: error)
                    .padding(.top, FlareDesign.Spacing.lg)
            }

            Button {
                Task { await auth.submit() }
            } label: {
                Label(auth.isBusy ? "Signing in..." : "Sign in", systemImage: "arrow.right.square")
                    .font(.system(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .foregroundStyle(.white)
                    .background(
                        LinearGradient(
                            colors: [FlareDesign.brand, Color(red: 0.55, green: 0.16, blue: 0.92)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: FlareDesign.Radius.small, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!auth.canLogin)
            .opacity(auth.canLogin ? 1 : 0.55)
            .padding(.top, FlareDesign.Spacing.xxl)

            VStack(spacing: FlareDesign.Spacing.sm) {
                Text("Your ID is assigned by the admin and shown in the invitation email")
                Text("ID-only sign-in; secure connection enabled")
            }
            .font(.caption)
            .foregroundStyle(FlareDesign.textTertiary)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .padding(.top, FlareDesign.Spacing.xl)
        }
        .padding(.horizontal, FlareDesign.Spacing.md)
        .padding(.top, 30)
        .padding(.bottom, 42)
        .background(Color.white)
    }

    private var serverConfigSection: some View {
        let transportMode = auth.draftBinding(\.transportMode)
        return VStack(alignment: .leading, spacing: FlareDesign.Spacing.md) {
            HStack(spacing: FlareDesign.Spacing.md) {
                Text("Server address (optional)")
                    .font(.system(size: 14))
                    .foregroundStyle(FlareDesign.textSecondary)
                Spacer()
                Menu {
                    ForEach(LoginTransportMode.allCases) { mode in
                        Button {
                            transportMode.wrappedValue = mode
                        } label: {
                            Label(mode.title, systemImage: protocolIcon(for: mode))
                        }
                    }
                } label: {
                    HStack(spacing: FlareDesign.Spacing.sm) {
                        Text(auth.loginDraft.transportMode.title)
                            .font(FlareDesign.Typography.callout)
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(FlareDesign.textPrimary)
                    .contentShape(Rectangle())
                }
            }

            LoginInputField(
                title: auth.loginDraft.visibleServerAddressLabel,
                placeholder: auth.loginDraft.visibleServerAddressPlaceholder,
                systemImage: protocolIcon(for: auth.loginDraft.transportMode),
                text: auth.visibleServerAddress
            )
            .padding(.top, FlareDesign.Spacing.xxs)

            if let label = auth.loginDraft.secondaryServerAddressLabel,
               let placeholder = auth.loginDraft.secondaryServerAddressPlaceholder {
                LoginInputField(
                    title: label,
                    placeholder: placeholder,
                    systemImage: "antenna.radiowaves.left.and.right",
                    text: auth.secondaryServerAddress
                )
                .padding(.top, FlareDesign.Spacing.xs)
            }
        }
    }

    private func protocolIcon(for mode: LoginTransportMode) -> String {
        switch mode {
        case .websocket:
            return "antenna.radiowaves.left.and.right"
        case .quic:
            return "bolt.horizontal.circle"
        case .race:
            return "arrow.triangle.branch"
        }
    }
}

private struct LoginErrorBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: FlareDesign.Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(FlareDesign.danger)
                .padding(.top, FlareDesign.Spacing.xxs)
            VStack(alignment: .leading, spacing: FlareDesign.Spacing.xs) {
                Text("Sign-in failed")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(FlareDesign.textPrimary)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(FlareDesign.textSecondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, FlareDesign.Spacing.md)
        .padding(.vertical, FlareDesign.Spacing.md)
        .background(FlareDesign.danger.opacity(0.11))
        .clipShape(RoundedRectangle(cornerRadius: FlareDesign.radius, style: .continuous))
    }
}

private struct LoginGridBackground: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Path { path in
                    let step: CGFloat = 40
                    var x: CGFloat = 0
                    while x <= proxy.size.width {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: proxy.size.height))
                        x += step
                    }

                    var y: CGFloat = 0
                    while y <= proxy.size.height {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                        y += step
                    }
                }
                .stroke(.white.opacity(0.11), lineWidth: 1)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct LoginInputField: View {
    let title: String
    let placeholder: String
    let systemImage: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: FlareDesign.Spacing.sm) {
            Text(title)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(FlareDesign.textPrimary)
            HStack(spacing: FlareDesign.Spacing.md) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(FlareDesign.textTertiary)
                    .frame(width: 18)
                TextField(placeholder, text: $text)
                    .font(FlareDesign.Typography.body)
                    .foregroundStyle(FlareDesign.textPrimary)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, FlareDesign.Spacing.lg)
            .frame(height: 48)
            .background(Color(red: 0.95, green: 0.95, blue: 0.96))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.black.opacity(0.04), lineWidth: 1)
            )
        }
    }
}
