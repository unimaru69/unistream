import XCTest
@testable import UniStreamTV

final class FeatureAccessTests: XCTestCase {

    /// Same suspension as the Flutter side: `FeatureAccess.canUse` returns
    /// `true` for everyone and `maxProfiles` returns 10, deliberately,
    /// while the monetisation refactor (single tier + 7-day trial) is
    /// pending — see the disabled branches kept in `Feature.swift`. The
    /// tests that assert a *denial* are skipped rather than rewritten, so
    /// re-enabling the gates re-enables the spec that describes them.
    private static let gatesSuspended =
        "Gates suspended pending the monetisation refactor — FeatureAccess "
        + "returns true / 10 for everyone. See Feature.swift."

    override func setUp() {
        super.setUp()
        DebugPlanOverride.current = nil
    }

    override func tearDown() {
        DebugPlanOverride.current = nil
        super.tearDown()
    }

    // MARK: - No Account

    func testNilAccountDeniesAll() throws {
        throw XCTSkip(Self.gatesSuspended)
        for feature in Feature.allCases {
            XCTAssertFalse(FeatureAccess.canUse(feature, account: nil))
        }
    }

    // MARK: - Trial

    func testActiveTrialGetsCloudSync() {
        let info = AccountInfo(id: "1", trialStartedAt: Date(), subscriptionTier: "trial")
        XCTAssertTrue(FeatureAccess.canUse(.cloudSync, account: info))
    }

    func testActiveTrialDeniedPremiumFeatures() throws {
        throw XCTSkip(Self.gatesSuspended)
        let info = AccountInfo(id: "1", trialStartedAt: Date(), subscriptionTier: "trial")
        XCTAssertFalse(FeatureAccess.canUse(.collections, account: info))
        XCTAssertFalse(FeatureAccess.canUse(.multipleProfiles, account: info))
        XCTAssertFalse(FeatureAccess.canUse(.parentalControls, account: info))
        XCTAssertFalse(FeatureAccess.canUse(.catchupReplay, account: info))
        XCTAssertFalse(FeatureAccess.canUse(.advancedSubtitles, account: info))
    }

    // MARK: - Basic

    func testBasicGetsCloudSync() {
        let info = AccountInfo(id: "1", subscriptionTier: "basic")
        XCTAssertTrue(FeatureAccess.canUse(.cloudSync, account: info))
    }

    func testBasicDeniedPremiumFeatures() throws {
        throw XCTSkip(Self.gatesSuspended)
        let info = AccountInfo(id: "1", subscriptionTier: "basic")
        XCTAssertFalse(FeatureAccess.canUse(.collections, account: info))
        XCTAssertFalse(FeatureAccess.canUse(.multipleProfiles, account: info))
    }

    // MARK: - Premium

    func testPremiumGetsAllFeatures() {
        let info = AccountInfo(id: "1", subscriptionTier: "premium")
        for feature in Feature.allCases {
            XCTAssertTrue(FeatureAccess.canUse(feature, account: info), "\(feature) should be accessible for premium")
        }
    }

    // MARK: - Debug Overrides

    func testDebugPremiumUnlocksAll() {
        DebugPlanOverride.current = "premium"
        let info = AccountInfo(id: "1", subscriptionTier: "basic")
        for feature in Feature.allCases {
            XCTAssertTrue(FeatureAccess.canUse(feature, account: info))
        }
    }

    func testDebugBasicBlocksPremiumFeatures() throws {
        throw XCTSkip(Self.gatesSuspended)
        DebugPlanOverride.current = "basic"
        let info = AccountInfo(id: "1", subscriptionTier: "premium")
        XCTAssertFalse(FeatureAccess.canUse(.collections, account: info))
        XCTAssertTrue(FeatureAccess.canUse(.cloudSync, account: info))
    }

    // MARK: - Max Profiles

    func testMaxProfilesBasic() throws {
        throw XCTSkip(Self.gatesSuspended)
        let info = AccountInfo(id: "1", subscriptionTier: "basic")
        XCTAssertEqual(FeatureAccess.maxProfiles(info), 1)
    }

    func testMaxProfilesPremium() {
        let info = AccountInfo(id: "1", subscriptionTier: "premium")
        XCTAssertEqual(FeatureAccess.maxProfiles(info), 10)
    }

    func testMaxProfilesNilAccount() throws {
        throw XCTSkip(Self.gatesSuspended)
        XCTAssertEqual(FeatureAccess.maxProfiles(nil), 1)
    }
}
