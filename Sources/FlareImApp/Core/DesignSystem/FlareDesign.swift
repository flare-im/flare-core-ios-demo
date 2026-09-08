import SwiftUI
import FlareIMUI

// FlareDesign 是 app 的设计门面,现已**委托给 kit 设计 token**
// (FlareColors / FlareSizes,源自 flare-im-design/tokens/tokens.json),
// 不再持有并行的硬编码色值/尺寸。调用点(FlareDesign.brand / .Spacing.lg 等)保持不变,
// 值统一收敛到 kit,与三端一致。app 目前按 light 呈现,故色取 FlareColors.light。
enum FlareDesign {
    private static let c = FlareColors.light

    static let brand = c.primary
    static let brandSoft = c.bgSelected
    static let accent = c.info
    static let appBackground = c.bgSecondary
    static let surface = c.bgPrimary
    static let surfaceAlt = c.bgTertiary
    static let textPrimary = c.textPrimary
    static let textSecondary = c.textSecondary
    static let textTertiary = c.textTertiary
    static let success = c.success
    static let warning = c.warning
    static let danger = c.error
    static let incoming = c.bubbleOther
    static let outgoing = c.bubbleSelf
    static let outgoingText = Color.white
    static let callBackground = Color(red: 0.07, green: 0.08, blue: 0.10)

    static let sidebarWidth: CGFloat = 340
    static let detailWidth: CGFloat = 320

    /// 向后兼容别名：等价于 `Radius.medium`。新代码直接用 `FlareDesign.Radius.*`。
    static let radius: CGFloat = Radius.medium

    /// 圆角标尺，委托到 kit `FlareSizes`（sm6/md8/lg10/xl14/2xl18/full999）。
    enum Radius {
        static let small = FlareSizes.radiusSm     // 6
        static let medium = FlareSizes.radiusMd    // 8
        static let large = FlareSizes.radiusLg     // 10
        static let xl = FlareSizes.radiusXl        // 14
        static let pill = FlareSizes.radiusFull    // 999
    }

    /// 间距标尺（4pt 基准网格），委托到 kit `FlareSizes`。
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs = FlareSizes.spacingXs       // 4
        static let sm = FlareSizes.spacingSm       // 8
        static let md = FlareSizes.spacingMd       // 12
        static let lg = FlareSizes.spacingLg       // 16
        static let xl = FlareSizes.spacingXl       // 20
        static let xxl = FlareSizes.spacing2xl     // 24
    }

    /// 字体标尺。集中字号/字重，便于全局统一与无障碍缩放。
    enum Typography {
        static let largeTitle = Font.system(size: 25, weight: .heavy)
        static let title = Font.system(size: 22, weight: .bold)
        static let headline = Font.system(size: 16, weight: .semibold)
        static let body = Font.system(size: 15, weight: .regular)
        static let callout = Font.system(size: 14, weight: .medium)
        static let caption = Font.caption
        static let captionStrong = Font.caption.weight(.semibold)
    }

    static func color(for tone: RuntimeTone) -> Color {
        switch tone {
        case .neutral: return textTertiary
        case .info: return accent
        case .success: return success
        case .warning: return warning
        case .danger: return danger
        }
    }
}

struct FlarePanel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(FlareDesign.surface)
            .clipShape(RoundedRectangle(cornerRadius: FlareDesign.Radius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FlareDesign.Radius.medium, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
    }
}

extension View {
    func flarePanel() -> some View {
        modifier(FlarePanel())
    }
}
