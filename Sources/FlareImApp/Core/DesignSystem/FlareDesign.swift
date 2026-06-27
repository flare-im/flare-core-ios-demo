import SwiftUI

enum FlareDesign {
    static let brand = Color(red: 0.49, green: 0.23, blue: 0.93)
    static let brandSoft = Color(red: 0.95, green: 0.92, blue: 1.0)
    static let accent = Color(red: 0.10, green: 0.46, blue: 0.82)
    static let appBackground = Color(red: 0.96, green: 0.96, blue: 0.97)
    static let surface = Color.white
    static let surfaceAlt = Color(red: 0.95, green: 0.95, blue: 0.97)
    static let textPrimary = Color(red: 0.07, green: 0.07, blue: 0.09)
    static let textSecondary = Color(red: 0.42, green: 0.45, blue: 0.50)
    static let textTertiary = Color(red: 0.64, green: 0.65, blue: 0.69)
    static let success = Color(red: 0.13, green: 0.77, blue: 0.37)
    static let warning = Color(red: 0.96, green: 0.62, blue: 0.04)
    static let danger = Color(red: 0.94, green: 0.27, blue: 0.27)
    static let incoming = Color(red: 0.93, green: 0.90, blue: 1.0)
    static let outgoing = brand
    static let outgoingText = Color.white
    static let callBackground = Color(red: 0.07, green: 0.08, blue: 0.10)

    static let sidebarWidth: CGFloat = 340
    static let detailWidth: CGFloat = 320

    /// 向后兼容别名：等价于 `Radius.medium`。新代码直接用 `FlareDesign.Radius.*`。
    static let radius: CGFloat = Radius.medium

    /// 圆角标尺（消除散落的 6–16 ad-hoc 取值，归并为 4 档；旧 9/10→medium、14→large）。
    enum Radius {
        static let small: CGFloat = 6
        static let medium: CGFloat = 8
        static let large: CGFloat = 12
        static let xl: CGFloat = 16
        static let pill: CGFloat = 999
    }

    /// 间距标尺（4pt 基准网格）。off-scale 取值按就近归并到这些档位。
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
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
