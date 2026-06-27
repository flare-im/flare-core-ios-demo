import FlareCoreAppleSDK
import SwiftUI

struct StatusBanner: View {
    let status: RuntimeStatus
    let error: String?

    var body: some View {
        HStack(spacing: FlareDesign.Spacing.md) {
            Image(systemName: status.productIcon)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: FlareDesign.Spacing.xxs) {
                Text(status.productLabel)
                    .font(.footnote.weight(.semibold))
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(FlareDesign.textSecondary)
                        .lineLimit(2)
                }
            }
            Spacer()
        }
        .padding(.horizontal, FlareDesign.Spacing.md)
        .padding(.vertical, FlareDesign.Spacing.sm)
        .background(color.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: FlareDesign.radius, style: .continuous))
    }

    private var detail: String? {
        if let error, !error.isEmpty {
            return error
        }
        return status.productDetail
    }

    private var color: Color {
        FlareDesign.color(for: status.productTone)
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String
    let symbol: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: FlareDesign.Spacing.lg) {
            Image(systemName: symbol)
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(FlareDesign.brand.opacity(0.55))
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(FlareDesign.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct KeyValueRows: View {
    let values: [(String, String)]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(values, id: \.0) { key, value in
                HStack(alignment: .top, spacing: FlareDesign.Spacing.md) {
                    Text(key)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(FlareDesign.textSecondary)
                        .frame(width: 128, alignment: .leading)
                    Text(value.isEmpty ? "-" : value)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, FlareDesign.Spacing.sm)
                if key != values.last?.0 {
                    Divider()
                }
            }
        }
    }
}

struct Pill: View {
    let text: String
    var color: Color = FlareDesign.brand

    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, FlareDesign.Spacing.sm)
            .padding(.vertical, FlareDesign.Spacing.xs)
            .foregroundStyle(color)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

struct StatusPill: View {
    let text: String
    var symbol: String?
    var tone: RuntimeTone = .neutral
    var filled = false

    var body: some View {
        HStack(spacing: FlareDesign.Spacing.xs) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.caption2.weight(.bold))
            }
            Text(text)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, FlareDesign.Spacing.sm)
        .padding(.vertical, FlareDesign.Spacing.xs)
        .foregroundStyle(filled ? .white : color)
        .background(filled ? color : color.opacity(0.11))
        .clipShape(Capsule())
    }

    private var color: Color {
        FlareDesign.color(for: tone)
    }
}

struct ProductMetricTile: View {
    let title: String
    let value: String
    let symbol: String
    var tone: RuntimeTone = .neutral

    var body: some View {
        HStack(spacing: FlareDesign.Spacing.sm) {
            Image(systemName: symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(FlareDesign.color(for: tone))
                .frame(width: 22, height: 22)
                .background(FlareDesign.color(for: tone).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: FlareDesign.Radius.small, style: .continuous))
            VStack(alignment: .leading, spacing: FlareDesign.Spacing.xxs) {
                Text(value)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(FlareDesign.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(FlareDesign.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }
            Spacer(minLength: 0)
        }
        .padding(FlareDesign.Spacing.sm)
        .background(FlareDesign.surfaceAlt)
        .clipShape(RoundedRectangle(cornerRadius: FlareDesign.radius, style: .continuous))
    }
}

struct LoadingOverlay: ViewModifier {
    let isVisible: Bool

    func body(content: Content) -> some View {
        content.overlay {
            if isVisible {
                ZStack {
                    Color.black.opacity(0.10)
                    ProgressView()
                        .padding(FlareDesign.Spacing.xl)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: FlareDesign.radius, style: .continuous))
                }
            }
        }
    }
}

extension View {
    func loadingOverlay(_ isVisible: Bool) -> some View {
        modifier(LoadingOverlay(isVisible: isVisible))
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: FlareDesign.Spacing.xs) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(FlareDesign.textPrimary)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(FlareDesign.textSecondary)
            }
        }
    }
}
