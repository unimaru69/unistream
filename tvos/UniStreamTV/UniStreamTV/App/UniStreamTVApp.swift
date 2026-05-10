import SwiftUI

@main
struct UniStreamTVApp: App {
    @State private var appState = AppState()
    @State private var needsPinUnlock = false

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.isCheckingSession {
                    SplashView()
                } else if !appState.isAuthenticated {
                    LoginView()
                } else if needsPinUnlock, let profile = appState.profileManager.activeProfile {
                    PinEntryView(
                        profileName: profile.name,
                        pinHash: profile.pinHash ?? ""
                    ) {
                        needsPinUnlock = false
                    } onCancel: {
                        // Deny access — go to profile picker instead
                        needsPinUnlock = false
                        appState.hasActiveProfile = false
                    }
                } else if !appState.hasActiveProfile {
                    ProfilePickerView()
                } else {
                    HomeTabView()
                }
            }
            .environment(appState)
            // Force dark mode app-wide. Without this tvOS would mix
            // dark-styled custom views with system-styled components
            // (Form rows, Toggles, Pickers) auto-resolved against the
            // user's system appearance — which on tvOS often defaults
            // to "auto" / "light" and produced low-contrast text on
            // our dark canvases. Pinning .dark guarantees every
            // system component picks its dark-mode palette, which is
            // calibrated to read on dark substrates.
            .preferredColorScheme(.dark)
            .task { @MainActor in
                await appState.checkExistingSession()
                // If restored profile has a PIN, require verification
                if appState.hasActiveProfile,
                   let profile = appState.profileManager.activeProfile,
                   profile.hasPin {
                    needsPinUnlock = true
                }
            }
            .onOpenURL { url in
                handleDeepLink(url)
            }
        }
    }

    /// Handles `unistream://play?key=live_1234` URLs coming from the Top Shelf extension.
    @MainActor
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "unistream",
              url.host == "play",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let key = components.queryItems?.first(where: { $0.name == "key" })?.value
        else { return }

        // Only act once auth + profile are ready — if not, stash and retry after Splash.
        guard appState.isAuthenticated, appState.hasActiveProfile else {
            // Retry shortly — AppState finishes session check within ~1s.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                handleDeepLink(url)
            }
            return
        }

        let api = appState.api
        let fav = appState.syncService.favorites[key]
        let title = fav?.name ?? key

        if key.hasPrefix("live_") {
            let sid = String(key.dropFirst("live_".count))
            if let streamUrl = api.liveStreamUrl(streamId: sid) {
                PlayerPresenter.playLive(url: streamUrl, title: title, contentKey: key)
            }
        } else if key.hasPrefix("vod_") {
            let sid = String(key.dropFirst("vod_".count))
            if let streamUrl = api.vodStreamUrl(streamId: sid, extension: fav?.containerExtension ?? "mp4") {
                PlayerPresenter.playVOD(url: streamUrl, title: title, contentKey: key)
            }
        } else if key.hasPrefix("ep_") {
            let eid = String(key.dropFirst("ep_".count))
            if let streamUrl = api.seriesStreamUrl(episodeId: eid, extension: fav?.containerExtension ?? "mp4") {
                PlayerPresenter.playVOD(url: streamUrl, title: title, contentKey: key)
            }
        }
    }
}
