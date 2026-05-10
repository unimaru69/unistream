import SwiftUI
import Kingfisher

/// Settings screen with profile, account, subscription, history, collections, parental.
struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var showSubscription = false
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var imageCacheSize: String = "…"
    @State private var showCachePurged = false
    // Use @AppStorage so SwiftUI re-renders the List when the override changes.
    @AppStorage("debug.plan.override") private var debugPlanRaw: String = ""
    private var debugPlanMode: String {
        get { debugPlanRaw.isEmpty ? "auto" : debugPlanRaw }
    }

    var body: some View {
        List {
            // Active profile
            if let profile = appState.profileManager.activeProfile {
                Section("Profil actif") {
                    HStack(spacing: 12) {
                        Text(profile.avatar)
                            .font(.title2)
                        VStack(alignment: .leading) {
                            Text(profile.name)
                                .font(.headline)
                            Text(profile.serverUrl)
                                .font(.caption)
                                .foregroundColor(DS.Colour.textSecondary)
                        }
                    }
                }
            }

            // Subscription
            Section("Abonnement") {
                subscriptionRow

                Button {
                    showSubscription = true
                } label: {
                    Label(
                        appState.authService.cachedAccountInfo?.hasActiveSubscription == true
                            ? "Gérer l'abonnement"
                            : "S'abonner",
                        systemImage: "crown"
                    )
                }
                .tint(Color(hex: 0x1B6B8A))
            }

            // Content management
            Section("Contenus") {
                NavigationLink(value: "history") {
                    Label("Historique de lecture", systemImage: "clock.arrow.circlepath")
                }

                if canUse(.collections) {
                    NavigationLink(value: "collections") {
                        HStack {
                            Label("Collections", systemImage: "folder.fill")
                            Spacer()
                            Text("\(appState.collectionsService.collections.count)")
                                .font(.caption)
                                .foregroundColor(DS.Colour.textSecondary)
                        }
                    }
                } else {
                    premiumLockedRow(label: "Collections", icon: "folder.fill", feature: .collections)
                }

                if canUse(.parentalControls) {
                    NavigationLink(value: "parental") {
                        HStack {
                            Label("Contrôle parental", systemImage: "lock.shield.fill")
                            Spacer()
                            if appState.parentalService.isEnabled {
                                Text("Activé")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                } else {
                    premiumLockedRow(label: "Contrôle parental", icon: "lock.shield.fill", feature: .parentalControls)
                }
            }

            // Profiles
            Section("Profils") {
                if canUse(.multipleProfiles) {
                    NavigationLink(value: "profiles") {
                        HStack {
                            Label("Gérer les profils", systemImage: "person.2.fill")
                            Spacer()
                            Text("\(appState.profileManager.profiles.count)")
                                .font(.caption)
                                .foregroundColor(DS.Colour.textSecondary)
                        }
                    }
                } else {
                    premiumLockedRow(label: "Multi-profils", icon: "person.2.fill", feature: .multipleProfiles)
                }
            }

            // Account
            Section("Compte") {
                if let email = appState.authService.currentUser?.email {
                    Label(email, systemImage: "envelope")
                        .foregroundColor(DS.Colour.textSecondary)
                }
            }

            // Playback
            Section {
                Toggle(isOn: Binding(
                    get: { PlayerPresenter.useVlcForLive },
                    set: { PlayerPresenter.useVlcForLive = $0 }
                )) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Lecteur VLC pour les directs")
                            Text("Recommandé pour HD/FHD. Désactivez pour utiliser le lecteur Apple natif.")
                                .font(.caption)
                                .foregroundColor(DS.Colour.textSecondary)
                        }
                    } icon: {
                        Image(systemName: "play.tv")
                    }
                }

                Toggle(isOn: Binding(
                    get: { PlayerPresenter.useVlcForVod },
                    set: { PlayerPresenter.useVlcForVod = $0 }
                )) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Lecteur VLC pour films & séries")
                            Text("VLC gère plus de formats que le lecteur Apple. Désactivez seulement si vous préférez l'interface native d'Apple TV.")
                                .font(.caption)
                                .foregroundColor(DS.Colour.textSecondary)
                        }
                    } icon: {
                        Image(systemName: "film.stack")
                    }
                }
            } header: {
                Text("Lecture")
            }

            // TMDB metadata enrichment
            TMDBSettingsSection()

            // Cache management
            Section("Cache") {
                HStack {
                    Label("Cache images", systemImage: "photo.stack")
                    Spacer()
                    Text(imageCacheSize)
                        .foregroundColor(DS.Colour.textSecondary)
                }

                HStack {
                    Label("Cache API", systemImage: "arrow.triangle.2.circlepath")
                    Spacer()
                    Text("\(appState.api.cacheEntryCount) entrées")
                        .foregroundColor(DS.Colour.textSecondary)
                }

                Button {
                    purgeAllCaches()
                } label: {
                    Label("Vider tous les caches", systemImage: "trash.circle")
                }
                .tint(.orange)
            }

            // Actions
            Section {
                Button("Changer de profil", systemImage: "arrow.triangle.2.circlepath") {
                    appState.parentalService.lock()
                    appState.hasActiveProfile = false
                }

                Button("Se déconnecter", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                    Task {
                        appState.parentalService.lock()
                        await appState.purchaseService.logOut()
                        try? await appState.authService.signOut()
                        appState.isAuthenticated = false
                        appState.hasActiveProfile = false
                    }
                }
            }

            // Debug — visible uniquement en Debug build
            #if DEBUG
            Section("Debug") {
                Picker(selection: Binding(
                    get: { debugPlanMode },
                    set: { debugPlanRaw = $0 == "auto" ? "" : $0 }
                )) {
                    Text("Auto (plan réel)").tag("auto")
                    Text("Forcer Basic").tag("basic")
                    Text("Forcer Premium").tag("premium")
                } label: {
                    Label("Plan override", systemImage: "hammer")
                }

                if !debugPlanRaw.isEmpty {
                    Text("Override actif : \(debugPlanRaw). Les fonctionnalités sont débloquées immédiatement.")
                        .font(.caption)
                        .foregroundColor(DS.Colour.textSecondary)
                }
            }
            #endif

            // Danger zone
            Section {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    if isDeleting {
                        ProgressView()
                    } else {
                        Label("Supprimer mon compte", systemImage: "trash")
                    }
                }
                .disabled(isDeleting)
            }
        }
        .navigationTitle("Réglages")
        .fullScreenCover(isPresented: $showSubscription) {
            SubscriptionView()
        }
        .onAppear { refreshCacheSize() }
        .alert("Cache vidé", isPresented: $showCachePurged) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Tous les caches ont été purgés.")
        }
        .alert("Supprimer le compte ?", isPresented: $showDeleteConfirm) {
            Button("Annuler", role: .cancel) {}
            Button("Supprimer", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("Cette action est irréversible. Toutes vos données seront supprimées.")
        }
    }

    // MARK: - Feature Gating

    private func canUse(_ feature: Feature) -> Bool {
        FeatureAccess.canUse(feature, account: appState.authService.cachedAccountInfo)
    }

    @ViewBuilder
    private func premiumLockedRow(label: String, icon: String, feature: Feature) -> some View {
        Button {
            showSubscription = true
        } label: {
            HStack {
                Label(label, systemImage: icon)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "crown.fill")
                        .font(.caption)
                    Text("Premium")
                        .font(.caption)
                }
                .foregroundColor(.yellow)
            }
        }
    }

    // MARK: - Subscription display

    @ViewBuilder
    private var subscriptionRow: some View {
        if let info = appState.authService.cachedAccountInfo {
            if info.isTrial {
                HStack {
                    Label("Essai gratuit", systemImage: "clock")
                    Spacer()
                    Text("\(info.trialDaysRemaining)j restants")
                        .foregroundColor(info.trialDaysRemaining <= 3 ? .red : .secondary)
                }
            } else if info.hasActiveSubscription {
                HStack {
                    Label(info.subscriptionTier.capitalized, systemImage: info.isPremium ? "crown.fill" : "star.fill")
                        .foregroundColor(info.isPremium ? .yellow : Color(hex: 0x1B6B8A))
                    Spacer()
                    if let expires = info.subscriptionExpiresAt {
                        Text("Expire \(expires, style: .date)")
                            .font(.caption)
                            .foregroundColor(DS.Colour.textSecondary)
                    }
                }
            } else if info.isTrialExpired {
                Label("Essai expiré", systemImage: "exclamationmark.triangle")
                    .foregroundColor(.red)
            } else {
                Label("Aucun abonnement", systemImage: "xmark.circle")
                    .foregroundColor(DS.Colour.textSecondary)
            }
        } else {
            Label("Chargement…", systemImage: "hourglass")
                .foregroundColor(DS.Colour.textSecondary)
        }
    }

    // MARK: - Cache

    private func refreshCacheSize() {
        ImageCache.default.calculateDiskStorageSize { result in
            Task { @MainActor in
                switch result {
                case .success(let size):
                    let mb = Double(size) / 1_000_000
                    if mb > 1 {
                        imageCacheSize = String(format: "%.1f Mo", mb)
                    } else {
                        imageCacheSize = String(format: "%.0f Ko", Double(size) / 1_000)
                    }
                case .failure:
                    imageCacheSize = "N/A"
                }
            }
        }
    }

    private func purgeAllCaches() {
        // Clear Kingfisher image cache
        ImageCache.default.clearMemoryCache()
        ImageCache.default.clearDiskCache {
            Task { @MainActor in
                refreshCacheSize()
            }
        }

        // Clear API response cache
        appState.api.clearStreamCache()

        // Clear URLSession cache
        URLCache.shared.removeAllCachedResponses()

        showCachePurged = true
    }

    // MARK: - Actions

    private func deleteAccount() {
        isDeleting = true
        Task {
            do {
                await appState.purchaseService.logOut()
                try await appState.authService.deleteAccount()
                appState.isAuthenticated = false
                appState.hasActiveProfile = false
            } catch {
                try? await appState.authService.signOut()
                appState.isAuthenticated = false
                appState.hasActiveProfile = false
            }
            isDeleting = false
        }
    }
}
