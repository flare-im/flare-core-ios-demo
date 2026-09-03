import XCTest
@testable import FlareImApp

/// iOS 的动作可用性必须与**核心** `domain::message_actions` 逐位一致。
///
/// 向量由核心生成（`cargo test action_availability_vectors`）；
/// 规则一改这里就红，逼你回来看 iOS 是否要跟着改。
final class MessageActionVectorsTests: XCTestCase {

    private struct Vector: Decodable {
        struct Input: Decodable {
            let isSelf: Bool
            let messageType: Int
            let status: Int
            let hasText: Bool
            let isPending: Bool
            let isPinned: Bool
            let isConnected: Bool
            let multiSelectMode: Bool
            let isFailed: Bool
            let isRead: Bool
        }
        struct Expected: Decodable {
            let canReply, canForward, canCopy, canEdit, canDelete, canRecall: Bool
            let canPin, canUnpin, canReact, canMultiSelect, canSave, canResend: Bool
        }
        let label: String
        let input: Input
        let expected: Expected
        let deliveryState: String
    }

    private struct Vectors: Decodable { let cases: [Vector] }

    func testAvailabilityMatchesCoreVectors() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // FlareImAppTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // flare-core-ios-app
            .deletingLastPathComponent()   // examples
            .deletingLastPathComponent()   // flare-im-core-client-sdk 根
        let url = root.appendingPathComponent("sdk-spec/message-action-vectors.json")
        let data = try Data(contentsOf: url)
        let vectors = try JSONDecoder().decode(Vectors.self, from: data)

        XCTAssertGreaterThanOrEqual(
            vectors.cases.count, 10,
            "向量太少，这条门禁形同虚设"
        )

        for vector in vectors.cases {
            let actual = MessageActions.availability(
                MessageActionInput(
                    isSelf: vector.input.isSelf,
                    messageType: vector.input.messageType,
                    status: vector.input.status,
                    hasText: vector.input.hasText,
                    isPending: vector.input.isPending,
                    isPinned: vector.input.isPinned,
                    isConnected: vector.input.isConnected,
                    multiSelectMode: vector.input.multiSelectMode,
                    isFailed: vector.input.isFailed
                )
            )
            let e = vector.expected
            let expected = MessageActionAvailability(
                canReply: e.canReply, canForward: e.canForward, canCopy: e.canCopy,
                canEdit: e.canEdit, canDelete: e.canDelete, canRecall: e.canRecall,
                canPin: e.canPin, canUnpin: e.canUnpin, canReact: e.canReact,
                canMultiSelect: e.canMultiSelect, canSave: e.canSave, canResend: e.canResend
            )
            XCTAssertEqual(actual, expected, "与核心不一致：\(vector.label)")

            // 送达状态同样对齐核心：iOS 的 deliveryState 派生逻辑见 MessageRowViews。
            let delivery = MessageActions.deliveryState(
                isSelf: vector.input.isSelf,
                status: vector.input.status,
                isRead: vector.input.isRead,
                isPending: vector.input.isPending,
                isFailed: vector.input.isFailed
            )
            XCTAssertEqual(
                delivery.rawValue, vector.deliveryState,
                "送达状态与核心不一致：\(vector.label)"
            )
        }
    }
}
