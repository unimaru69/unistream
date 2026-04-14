import Foundation
import RevenueCat
import os

/// RevenueCat wrapper — mirrors Flutter's `purchase_service.dart`.
@MainActor @Observable
final class PurchaseService {
    private let logger = Logger(subsystem: "fr.unimaru.unistream.tv", category: "Purchase")

    private(set) var isAvailable = false
    private(set) var offerings: Offerings?
    private(set) var customerInfo: CustomerInfo?
    private(set) var isLoading = false
    private(set) var error: String?

    // MARK: - Computed

    /// Current entitlement identifier (e.g. "basic", "premium") or nil.
    var activeEntitlement: String? {
        guard let info = customerInfo else { return nil }
        if info.entitlements["premium"]?.isActive == true { return "premium" }
        if info.entitlements["basic"]?.isActive == true { return "basic" }
        return nil
    }

    var hasActiveSubscription: Bool { activeEntitlement != nil }
    var isPremium: Bool { activeEntitlement == "premium" }
    var isBasicOrAbove: Bool { activeEntitlement != nil }

    // MARK: - Initialization

    func configure(appUserId: String?) {
        Purchases.logLevel = .warn
        Purchases.configure(
            with: .init(withAPIKey: Constants.revenueCatApiKey)
                .with(appUserID: appUserId)
        )
        isAvailable = true
        logger.info("RevenueCat configured for user: \(appUserId ?? "anonymous")")

        // Listen for customer info changes
        Purchases.shared.delegate = PurchaseDelegateHandler.shared
        PurchaseDelegateHandler.shared.onChange = { [weak self] info in
            Task { @MainActor in
                self?.customerInfo = info
                self?.logger.info("Customer info updated: \(info.entitlements.active.keys.joined(separator: ", "))")
            }
        }

        // Fetch initial state
        Task { await refreshCustomerInfo() }
    }

    // MARK: - Offerings

    func fetchOfferings() async {
        guard isAvailable else { return }
        isLoading = true
        error = nil
        do {
            offerings = try await Purchases.shared.offerings()
            logger.info("Offerings loaded: \(self.offerings?.current?.availablePackages.count ?? 0) packages")
        } catch {
            self.error = error.localizedDescription
            logger.error("fetchOfferings failed: \(error.localizedDescription)")
        }
        isLoading = false
    }

    // MARK: - Purchase

    func purchase(package: Package) async -> Bool {
        guard isAvailable else { return false }
        isLoading = true
        error = nil
        do {
            let result = try await Purchases.shared.purchase(package: package)
            customerInfo = result.customerInfo
            if !result.userCancelled {
                logger.info("Purchase completed: \(package.identifier)")
                isLoading = false
                return true
            } else {
                logger.info("Purchase cancelled by user")
            }
        } catch {
            self.error = error.localizedDescription
            logger.error("Purchase failed: \(error.localizedDescription)")
        }
        isLoading = false
        return false
    }

    // MARK: - Restore

    func restorePurchases() async -> Bool {
        guard isAvailable else { return false }
        isLoading = true
        error = nil
        do {
            customerInfo = try await Purchases.shared.restorePurchases()
            let active = customerInfo?.entitlements.active.isEmpty == false
            logger.info("Restore completed. Active: \(active)")
            isLoading = false
            return active
        } catch {
            self.error = error.localizedDescription
            logger.error("Restore failed: \(error.localizedDescription)")
        }
        isLoading = false
        return false
    }

    // MARK: - Refresh

    func refreshCustomerInfo() async {
        guard isAvailable else { return }
        do {
            customerInfo = try await Purchases.shared.customerInfo()
        } catch {
            logger.warning("refreshCustomerInfo failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Logout

    func logOut() async {
        guard isAvailable else { return }
        customerInfo = try? await Purchases.shared.logOut()

        offerings = nil
    }
}

// MARK: - Delegate (non-isolated helper)

private final class PurchaseDelegateHandler: NSObject, PurchasesDelegate, Sendable {
    static let shared = PurchaseDelegateHandler()

    // Use nonisolated(unsafe) for the closure since RevenueCat calls on main thread
    nonisolated(unsafe) var onChange: ((CustomerInfo) -> Void)?

    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        onChange?(customerInfo)
    }
}
