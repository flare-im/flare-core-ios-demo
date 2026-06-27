import FlareCoreAppleSDK
import AVFoundation
import AVKit
import SwiftUI

struct RichCardMessageView: View {
    let title: String
    let detail: String
    let symbol: String
    let outgoing: Bool

    var body: some View {
        HStack(alignment: .top, spacing: FlareDesign.Spacing.md) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(outgoing ? FlareDesign.brand : .white)
                .frame(width: 36, height: 36)
                .background(outgoing ? Color.white.opacity(0.88) : FlareDesign.brand)
                .clipShape(RoundedRectangle(cornerRadius: FlareDesign.Radius.medium, style: .continuous))
            VStack(alignment: .leading, spacing: FlareDesign.Spacing.xs) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(outgoing ? Color.white.opacity(0.76) : FlareDesign.textSecondary)
                    .lineLimit(3)
            }
        }
        .frame(minWidth: 190, alignment: .leading)
    }
}

struct StructuredWorkMessageView: View {
    let content: MessageContent
    let outgoing: Bool

    var body: some View {
        RichCardMessageView(
            title: title,
            detail: detail,
            symbol: symbol,
            outgoing: outgoing
        )
    }

    private var title: String {
        switch content.contentType {
        case .schedule: return content.stringValue("title") ?? String(localized: "Schedule")
        case .task: return content.stringValue("title") ?? String(localized: "Task")
        case .vote: return content.stringValue("title") ?? String(localized: "Vote")
        default: return content.contentType.title
        }
    }

    private var detail: String {
        switch content.contentType {
        case .schedule:
            let start = formattedDate(content.int64Value("startTimeMs"))
            let end = formattedDate(content.int64Value("endTimeMs"))
            let range = [start, end].compactMap { $0 }.joined(separator: " - ")
            return range.isEmpty ? content.previewText : range
        case .task:
            return content.stringValue("status").map { String(localized: "Status: \($0)") } ?? content.previewText
        case .vote:
            let options = stringArray("options")
            return options.isEmpty ? content.previewText : options.joined(separator: " · ")
        default:
            return content.previewText
        }
    }

    private var symbol: String {
        switch content.contentType {
        case .schedule: return "calendar"
        case .task: return "checkmark.square"
        case .vote: return "chart.bar.doc.horizontal"
        default: return "checklist"
        }
    }

    private func formattedDate(_ millis: Int64?) -> String? {
        guard let millis, millis > 0 else { return nil }
        let date = Date(timeIntervalSince1970: TimeInterval(millis) / 1000)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "M/d HH:mm"
        return formatter.string(from: date)
    }

    private func stringArray(_ key: String) -> [String] {
        guard let raw = content.data[key]?.value else { return [] }
        if let values = raw as? [String] { return values.filter { !$0.isEmpty } }
        if let values = raw as? [Any] {
            return values.compactMap { $0 as? String }.filter { !$0.isEmpty }
        }
        return []
    }
}
