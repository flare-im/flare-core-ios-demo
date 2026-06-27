import FlareCoreAppleSDK
import AVFoundation
import AVKit
import SwiftUI

struct ComposerFormDraft: Identifiable {
    let id = UUID()
    let kind: ComposerFormKind
}

enum ComposerFormKind: String, Identifiable {
    case imageFallback
    case video
    case location
    case card
    case task
    case schedule
    case poll
    case link
    case miniProgram
    case notification
    case announcement

    var id: String { rawValue }

    var op: MessageBuildOp {
        switch self {
        case .imageFallback: return .createImage
        case .video: return .createVideo
        case .location: return .createLocation
        case .card: return .createCard
        case .task: return .createTask
        case .schedule: return .createSchedule
        case .poll: return .createVote
        case .link: return .createLinkCard
        case .miniProgram: return .createMiniProgram
        case .notification: return .createNotification
        case .announcement: return .createAnnouncement
        }
    }

    var sheetTitle: String {
        switch self {
        case .imageFallback: return String(localized: "Send image")
        case .video: return String(localized: "Send video")
        case .location: return String(localized: "Send location")
        case .card: return String(localized: "Send contact")
        case .task: return String(localized: "Send task")
        case .schedule: return String(localized: "Send schedule")
        case .poll: return String(localized: "Send poll")
        case .link: return String(localized: "Send link")
        case .miniProgram: return String(localized: "Send mini program")
        case .notification: return String(localized: "Send notification")
        case .announcement: return String(localized: "Send announcement")
        }
    }

    var badge: String {
        switch self {
        case .imageFallback: return "image"
        case .video: return "video"
        case .location: return "location"
        case .card: return "card"
        case .task: return "task"
        case .schedule: return "schedule"
        case .poll: return "poll"
        case .link: return "link"
        case .miniProgram: return "mini"
        case .notification: return "notice"
        case .announcement: return "announce"
        }
    }

    var summary: String {
        switch self {
        case .imageFallback: return String(localized: "Add an image caption as a fallback when album selection is unavailable")
        case .video: return String(localized: "Provide the video ID and caption")
        case .location: return String(localized: "Send a place name, address, and coordinates")
        case .card: return String(localized: "Send a contact or business card")
        case .task: return String(localized: "Send a task title and participants")
        case .schedule: return String(localized: "Send a title, time, location, and participants")
        case .poll: return String(localized: "Send a question and options")
        case .link: return String(localized: "Send a link URL and card description")
        case .miniProgram: return String(localized: "Send a mini program entry")
        case .notification: return String(localized: "Send a notification title and body")
        case .announcement: return String(localized: "Send an announcement title and body")
        }
    }

    var preferredSheetHeight: CGFloat {
        switch self {
        case .schedule, .poll, .location:
            return 560
        default:
            return 500
        }
    }
}

struct ComposerInputFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    let draft: ComposerFormDraft
    let currentUserId: String?
    let onSubmit: ([String: Any]) -> Void

    @State private var title = ""
    @State private var detail = ""
    @State private var extra = ""
    @State private var participants = ""
    @State private var startDate = Date().addingTimeInterval(30 * 60)
    @State private var endDate = Date().addingTimeInterval(90 * 60)

    init(draft: ComposerFormDraft, currentUserId: String?, onSubmit: @escaping ([String: Any]) -> Void) {
        self.draft = draft
        self.currentUserId = currentUserId
        self.onSubmit = onSubmit
        _participants = State(initialValue: currentUserId ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(draft.kind.sheetTitle)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(FlareDesign.textPrimary)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(FlareDesign.textSecondary)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, FlareDesign.Spacing.xl)
            .padding(.top, FlareDesign.Spacing.xl)
            .padding(.bottom, FlareDesign.Spacing.sm)

            HStack(spacing: FlareDesign.Spacing.sm) {
                Text(draft.kind.badge)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FlareDesign.textSecondary)
                    .padding(.horizontal, FlareDesign.Spacing.sm)
                    .padding(.vertical, FlareDesign.Spacing.xs)
                    .background(FlareDesign.surfaceAlt)
                    .clipShape(Capsule())
                Text(draft.kind.summary)
                    .font(.caption)
                    .foregroundStyle(FlareDesign.textSecondary)
                    .lineLimit(2)
            }
            .padding(.horizontal, FlareDesign.Spacing.xl)
            .padding(.bottom, FlareDesign.Spacing.lg)

            ScrollView {
                VStack(alignment: .leading, spacing: FlareDesign.Spacing.lg) {
                    fields
                }
                .padding(.horizontal, FlareDesign.Spacing.xl)
                .padding(.bottom, FlareDesign.Spacing.xl)
            }

            Divider()
            HStack(spacing: FlareDesign.Spacing.md) {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                Button("Send") {
                    onSubmit(payload)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(FlareDesign.brand)
                .disabled(!isValid)
            }
            .padding(.horizontal, FlareDesign.Spacing.xl)
            .padding(.vertical, FlareDesign.Spacing.lg)
        }
        .background(FlareDesign.surface)
    }

    @ViewBuilder
    private var fields: some View {
        switch draft.kind {
        case .imageFallback:
            inputField(String(localized: "Image caption"), placeholder: "例如：现场照片", text: $title)
        case .video:
            inputField(String(localized: "Video ID"), placeholder: "video-id", text: $title)
            inputField(String(localized: "Description"), placeholder: "视频说明", text: $detail)
        case .location:
            inputField(String(localized: "Place name"), placeholder: "例如：上海办公室", text: $title)
            inputField(String(localized: "Address"), placeholder: "例如：世纪大道 100 号", text: $detail)
            inputField(String(localized: "Coordinates (optional)"), placeholder: "31.2304,121.4737", text: $extra)
        case .card:
            inputField(String(localized: "Name"), placeholder: "名片标题", text: $title)
            inputField(String(localized: "Description"), placeholder: "职位、部门或备注", text: $detail)
            inputField(String(localized: "Business ID"), placeholder: "card-id", text: $extra)
        case .task:
            inputField(String(localized: "Task title"), placeholder: "例如：确认 iOS 消息输入区", text: $title)
            inputField(String(localized: "Participants"), placeholder: "多个 ID 用空格或逗号分隔", text: $participants)
        case .schedule:
            inputField(String(localized: "Title / name"), placeholder: "例如：产品评审", text: $title)
            DatePicker("Start time", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                .font(.subheadline)
            DatePicker("End time", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                .font(.subheadline)
            inputField(String(localized: "Venue"), placeholder: "会议室或线上地址", text: $detail)
            inputField(String(localized: "Participants"), placeholder: "多个 ID 用空格或逗号分隔", text: $participants)
        case .poll:
            inputField(String(localized: "Poll title"), placeholder: "例如：选择发布时间", text: $title)
            multilineField(String(localized: "Options"), placeholder: "每行一个选项", text: $detail)
            inputField(String(localized: "Participants"), placeholder: "可选，多个 ID 用空格或逗号分隔", text: $participants)
        case .link:
            inputField(String(localized: "Link"), placeholder: "https://", text: $title)
            inputField(String(localized: "Title"), placeholder: "卡片标题", text: $detail)
            inputField(String(localized: "Description"), placeholder: "卡片摘要", text: $extra)
        case .miniProgram:
            inputField(String(localized: "Mini program ID"), placeholder: "app-id", text: $title)
            inputField(String(localized: "Title"), placeholder: "入口标题", text: $detail)
            inputField(String(localized: "Page path"), placeholder: "/pages/home", text: $extra)
        case .notification, .announcement:
            inputField(String(localized: "Title"), placeholder: "请输入标题", text: $title)
            multilineField(String(localized: "Body"), placeholder: "请输入正文", text: $detail)
        }
    }

    private var payload: [String: Any] {
        switch draft.kind {
        case .imageFallback:
            return [
                "imageId": "manual-image-\(UUID().uuidString)",
                "description": trimmed(title, fallback: "图片")
            ]
        case .video:
            return [
                "videoId": trimmed(title, fallback: "ios-video-\(UUID().uuidString)"),
                "description": trimmed(detail, fallback: "视频")
            ]
        case .location:
            let coordinate = parseCoordinate(extra)
            return [
                "title": trimmed(title, fallback: "位置"),
                "address": trimmed(detail, fallback: title),
                "latitude": coordinate?.latitude ?? 31.2304,
                "longitude": coordinate?.longitude ?? 121.4737
            ]
        case .card:
            return [
                "id": trimmed(extra, fallback: "card-\(UUID().uuidString)"),
                "title": trimmed(title, fallback: "名片"),
                "subtitle": trimmed(detail, fallback: currentUserId ?? "")
            ]
        case .task:
            return [
                "title": trimmed(title, fallback: "任务"),
                "participantUserIds": participants
            ]
        case .schedule:
            let location = detail.trimmingCharacters(in: .whitespacesAndNewlines)
            let displayTitle = location.isEmpty ? trimmed(title, fallback: "日程") : "\(trimmed(title, fallback: "日程")) · \(location)"
            return [
                "title": displayTitle,
                "startTimeMs": Int(startDate.timeIntervalSince1970 * 1000),
                "endTimeMs": Int(max(endDate.timeIntervalSince1970, startDate.addingTimeInterval(30 * 60).timeIntervalSince1970) * 1000),
                "participantUserIds": participants
            ]
        case .poll:
            return [
                "title": trimmed(title, fallback: "投票"),
                "options": optionList,
                "participantUserIds": participants
            ]
        case .link:
            return [
                "url": trimmed(title, fallback: "https://flare.local"),
                "title": trimmed(detail, fallback: title),
                "description": trimmed(extra, fallback: "")
            ]
        case .miniProgram:
            return [
                "appId": trimmed(title, fallback: "flare-mini"),
                "title": trimmed(detail, fallback: "小程序"),
                "pagePath": trimmed(extra, fallback: "/")
            ]
        case .notification:
            return [
                "title": trimmed(title, fallback: "通知"),
                "body": trimmed(detail, fallback: "")
            ]
        case .announcement:
            return [
                "title": trimmed(title, fallback: "公告"),
                "body": trimmed(detail, fallback: "")
            ]
        }
    }

    private var isValid: Bool {
        switch draft.kind {
        case .poll:
            return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && optionList.count >= 2
        case .link:
            return URL(string: title.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
        case .notification, .announcement:
            return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default:
            return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private var optionList: [String] {
        detail
            .split { $0 == "\n" || $0 == "," || $0 == "，" }
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func inputField(_ title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: FlareDesign.Spacing.sm) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(FlareDesign.textSecondary)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .padding(.horizontal, FlareDesign.Spacing.md)
                .padding(.vertical, FlareDesign.Spacing.md)
                .background(FlareDesign.surface)
                .clipShape(RoundedRectangle(cornerRadius: FlareDesign.Radius.medium, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: FlareDesign.Radius.medium, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )
        }
    }

    private func multilineField(_ title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: FlareDesign.Spacing.sm) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(FlareDesign.textSecondary)
            TextEditor(text: text)
                .frame(minHeight: 90)
                .padding(FlareDesign.Spacing.sm)
                .background(FlareDesign.surface)
                .clipShape(RoundedRectangle(cornerRadius: FlareDesign.Radius.medium, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: FlareDesign.Radius.medium, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if text.wrappedValue.isEmpty {
                        Text(placeholder)
                            .font(.body)
                            .foregroundStyle(FlareDesign.textTertiary)
                            .padding(.horizontal, FlareDesign.Spacing.lg)
                            .padding(.vertical, FlareDesign.Spacing.lg)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    private func trimmed(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private func parseCoordinate(_ value: String) -> (latitude: Double, longitude: Double)? {
        let parts = value
            .split { $0 == "," || $0 == "，" || $0 == " " }
            .map { Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        guard parts.count >= 2, let latitude = parts[0], let longitude = parts[1] else { return nil }
        return (latitude, longitude)
    }
}
