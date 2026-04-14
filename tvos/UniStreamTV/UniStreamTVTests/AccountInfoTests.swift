import XCTest
@testable import UniStreamTV

final class AccountInfoTests: XCTestCase {

    // MARK: - Trial Logic

    func testFreshTrialHasAccess() {
        let info = AccountInfo(id: "1", trialStartedAt: Date(), subscriptionTier: "trial")
        XCTAssertTrue(info.isTrial)
        XCTAssertTrue(info.isTrialActive)
        XCTAssertFalse(info.isTrialExpired)
        XCTAssertTrue(info.hasAccess)
        XCTAssertGreaterThan(info.trialDaysRemaining, 0)
    }

    func testExpiredTrialHasNoAccess() {
        let past = Calendar.current.date(byAdding: .day, value: -20, to: Date())!
        let info = AccountInfo(id: "1", trialStartedAt: past, subscriptionTier: "trial")
        XCTAssertTrue(info.isTrial)
        XCTAssertFalse(info.isTrialActive)
        XCTAssertTrue(info.isTrialExpired)
        XCTAssertFalse(info.hasAccess)
        XCTAssertEqual(info.trialDaysRemaining, 0)
    }

    func testTrialDaysBoundary() {
        let exactlyAtLimit = Calendar.current.date(byAdding: .day, value: -14, to: Date())!
        let info = AccountInfo(id: "1", trialStartedAt: exactlyAtLimit, subscriptionTier: "trial")
        XCTAssertEqual(info.trialDaysRemaining, 0)
        XCTAssertTrue(info.isTrialExpired)
    }

    func testNonTrialHasZeroTrialDays() {
        let info = AccountInfo(id: "1", subscriptionTier: "basic")
        XCTAssertFalse(info.isTrial)
        XCTAssertEqual(info.trialDaysRemaining, 0)
    }

    // MARK: - Subscription Logic

    func testBasicHasActiveSubscription() {
        let info = AccountInfo(id: "1", subscriptionTier: "basic")
        XCTAssertTrue(info.hasActiveSubscription)
        XCTAssertTrue(info.isBasicOrAbove)
        XCTAssertFalse(info.isPremium)
        XCTAssertTrue(info.hasAccess)
    }

    func testPremiumHasActiveSubscription() {
        let info = AccountInfo(id: "1", subscriptionTier: "premium")
        XCTAssertTrue(info.hasActiveSubscription)
        XCTAssertTrue(info.isPremium)
        XCTAssertTrue(info.hasAccess)
    }

    func testExpiredSubscriptionHasNoAccess() {
        let past = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let info = AccountInfo(id: "1", subscriptionTier: "basic", subscriptionExpiresAt: past)
        XCTAssertFalse(info.hasActiveSubscription)
        XCTAssertFalse(info.hasAccess)
    }

    func testNilExpiryMeansLifetime() {
        let info = AccountInfo(id: "1", subscriptionTier: "premium", subscriptionExpiresAt: nil)
        XCTAssertTrue(info.hasActiveSubscription)
    }

    func testFutureExpiryIsActive() {
        let future = Calendar.current.date(byAdding: .month, value: 1, to: Date())!
        let info = AccountInfo(id: "1", subscriptionTier: "basic", subscriptionExpiresAt: future)
        XCTAssertTrue(info.hasActiveSubscription)
    }
}
