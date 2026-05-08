import Foundation
import os

/// Central observable state coordinating auth, profiles, and API access.
@MainActor @Observable
final class AppState {
    private let logger = Logger(subsystem: "fr.unimaru.unistream.tv", category: "App")

    // Services
    let authService = AuthService()
    let profileManager = ProfileManager()
    let api = XtreamAPIService()
    let syncService = SyncService()
    let purchaseService = PurchaseService()
    let parentalService = ParentalService()
    let collectionsService = CollectionsService()
    let reminderService = EPGReminderService()
    /// Lazy full-catalog index used by `CastFilmographyView` to
    /// resolve a TMDB credit ("est-ce que cet acteur a tourné autre
    /// chose que j'ai dans mon catalogue ?") without forcing the
    /// user to navigate every category first.
    let catalogIndex = CatalogIndex()

    // Navigation state
    var isAuthenticated = false
    var hasActiveProfile = false
    var isCheckingSession = true

    // ViewModels — owned by AppState to survive view re-renders
    var liveVM: LiveViewModel?
    var vodVM: VODViewModel?
    var seriesVM: SeriesViewModel?
    var playerVM: PlayerViewModel?

    // MARK: - Initialization

    /// Check for existing Supabase session on app launch.
    func checkExistingSession() async {
        defer { isCheckingSession = false }

        // Initialize reminders (independent of auth)
        reminderService.initialize()

        // Demo mode: skip auth and server setup entirely.
        if DemoMode.isActive {
            logger.info("Demo mode — skipping auth")
            isAuthenticated = true
            hasActiveProfile = true
            setupVMs()
            return
        }

        // Fresh install detection: on tvOS, the Keychain (where Supabase stores
        // the session) SURVIVES app uninstallation, but UserDefaults doesn't.
        // If our sentinel flag is absent, this is a fresh install — force sign-out
        // to avoid landing on a half-connected state (auth OK but no IPTV profile).
        let installFlag = "app.installed.v1"
        if !UserDefaults.standard.bool(forKey: installFlag) {
            logger.info("Fresh install detected — clearing any stale session")
            try? await authService.signOut()
            UserDefaults.standard.set(true, forKey: installFlag)
        }

        if authService.isAuthenticated {
            isAuthenticated = true
            logger.info("Existing session found")

            // Configure RevenueCat + fetch account info
            purchaseService.configure(appUserId: authService.userId)
            Task { _ = await authService.fetchAccountInfo() }

            // Check if we have a saved profile
            if profileManager.activeProfile != nil {
                hasActiveProfile = true
                await setupAndConnect()
            }
        }
    }

    // MARK: - Auth Flow

    /// Called after successful sign-in.
    func onSignIn() async {
        isAuthenticated = true
        // Configure RevenueCat + fetch account info
        purchaseService.configure(appUserId: authService.userId)
        Task { _ = await authService.fetchAccountInfo() }

        if profileManager.activeProfile != nil {
            hasActiveProfile = true
            await setupAndConnect()
        }
    }

    /// Called after server setup succeeds (already authenticated).
    func onServerConfigured() {
        hasActiveProfile = true
        setupVMs()
        // Configure sync with the freshly created profile and pull remote data
        // (favorites, watch progress, collections) so the user finds them on
        // this device too.
        if let profile = profileManager.activeProfile,
           let uid = authService.userId {
            let hash = SupabaseConfig.profileHash(
                serverUrl: profile.serverUrl,
                username: profile.username
            )
            syncService.configure(profileHash: hash, userId: uid)
            PlayerPresenter.syncService = syncService
            collectionsService.configure(
                profilePrefix: "\(profile.serverUrl)_\(profile.username)"
            )
            parentalService.configure(
                profilePrefix: "\(profile.serverUrl)_\(profile.username)"
            )
            Task { await syncService.pullAll() }
        }
    }

    // MARK: - Private

    private func setupVMs() {
        guard liveVM == nil else { return }
        liveVM = LiveViewModel(api: api)
        vodVM = VODViewModel(api: api)
        seriesVM = SeriesViewModel(api: api)
        let pvm = PlayerViewModel(api: api)
        pvm.syncService = syncService
        playerVM = pvm
        catalogIndex.configure(api: api)
        logger.info("ViewModels created")
    }

    private func setupAndConnect() async {
        guard let profile = profileManager.activeProfile else { return }

        api.configure(
            serverUrl: profile.serverUrl,
            username: profile.username,
            password: profile.password
        )

        if !api.isAuthenticated {
            do {
                _ = try await api.authenticate()
            } catch {
                logger.error("Auto-connect failed: \(error.localizedDescription)")
            }
        }

        // Configure sync
        if let uid = authService.userId {
            let hash = SupabaseConfig.profileHash(serverUrl: profile.serverUrl, username: profile.username)
            syncService.configure(profileHash: hash, userId: uid)
            PlayerPresenter.syncService = syncService
            Task { await syncService.pullAll() }
        }

        // Configure parental controls + collections for this profile
        let profilePrefix = "\(profile.serverUrl)_\(profile.username)"
        parentalService.configure(profilePrefix: profilePrefix)
        collectionsService.configure(profilePrefix: profilePrefix)

        setupVMs()
    }
}
