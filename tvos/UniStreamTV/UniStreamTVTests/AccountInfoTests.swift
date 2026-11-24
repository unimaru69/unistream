import XCTest
@testable import UniStreamTV

final class AccountInfoTests: XCTestCase {
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    func testDecodesTheAccountRow() throws {
        let json = #"{"id":"user-1","email":"someone@example.invalid","created_at":"2026-04-10T08:00:00Z"}"#
        let info = try decoder.decode(AccountInfo.self, from: Data(json.utf8))
        XCTAssertEqual(info.id, "user-1")
        XCTAssertEqual(info.email, "someone@example.invalid")
        XCTAssertNotNil(info.createdAt)
    }

    /// `user_accounts` still has the trial and subscription columns of the
    /// abandoned paid model. The app must not depend on them.
    func testIgnoresLegacyTrialAndSubscriptionColumns() throws {
        let json = #"{"id":"user-1","email":"","trial_started_at":"2020-01-01T00:00:00Z","subscription_tier":"trial","subscription_expires_at":"2020-02-01T00:00:00Z","cross_platform_license":false}"#
        let info = try decoder.decode(AccountInfo.self, from: Data(json.utf8))
        XCTAssertEqual(info.id, "user-1")
        XCTAssertNil(info.createdAt)
    }
}
