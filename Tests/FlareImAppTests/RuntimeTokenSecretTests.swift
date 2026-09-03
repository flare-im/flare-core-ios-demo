import XCTest

/// 登录页必须露出「接入 token」和「签名密钥」两个运行时入口。
///
/// 此前这两项只在 Settings 里：想"只输 user id 就登录"得先去翻设置。
/// 密钥做成运行时输入而不是打进安装包——打进去等于让任何拿到安装包的人伪造任意用户身份。
final class RuntimeTokenSecretTests: XCTestCase {
    func testLoginPageBindsTokenAndSecret() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let src = try String(
            contentsOf: root.appendingPathComponent("Sources/FlareImApp/Features/Auth/LoginView.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(src.contains(#"auth.draftBinding(\.tokenSecret)"#), "登录页缺少签名密钥入口")
        XCTAssertTrue(src.contains(#"auth.draftBinding(\.tokenOverride)"#), "登录页缺少接入 token 入口")
    }
}
