import SwiftUI

/// Profile selection screen — choose existing profile or add new one.
struct ProfilePickerView: View {
    @Environment(AppState.self) private var appState
    @State private var showAddServer = false
    @State private var pinProfile: Profile?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x0E0B1E), Color(hex: 0x161230)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 48) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.linearGradient(
                            colors: [Color(hex: 0x1B6B8A), Color(hex: 0x2A8AB0)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))

                    Text("Qui regarde ?")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }

                // Existing profiles as cards
                if !appState.profileManager.profiles.isEmpty {
                    HStack(spacing: 32) {
                        ForEach(appState.profileManager.profiles, id: \.id) { profile in
                            Button {
                                selectProfile(profile)
                            } label: {
                                VStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: 0x1B6B8A).opacity(0.2))
                                            .frame(width: 100, height: 100)

                                        Text(profile.avatar)
                                            .font(.system(size: 44))

                                        if profile.id == appState.profileManager.activeProfile?.id {
                                            Circle()
                                                .strokeBorder(Color(hex: 0x1B6B8A), lineWidth: 3)
                                                .frame(width: 104, height: 104)
                                        }
                                    }

                                    Text(profile.name)
                                        .font(.headline)
                                        .foregroundColor(.white)

                                    Text(profile.serverUrl
                                        .replacingOccurrences(of: "http://", with: "")
                                        .replacingOccurrences(of: "https://", with: "")
                                        .prefix(25)
                                    )
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.4))
                                    .lineLimit(1)
                                }
                                .frame(width: 160)
                            }
                            .buttonStyle(.tvCard)
                        }

                        // Add new profile button
                        Button {
                            showAddServer = true
                        } label: {
                            VStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.05))
                                        .frame(width: 100, height: 100)

                                    Image(systemName: "plus")
                                        .font(.system(size: 36, weight: .light))
                                        .foregroundColor(.white.opacity(0.5))
                                }

                                Text("Ajouter")
                                    .font(.headline)
                                    .foregroundColor(.white.opacity(0.6))

                                Text(" ")
                                    .font(.caption2)
                            }
                            .frame(width: 160)
                        }
                        .buttonStyle(.tvCard)
                    }
                } else {
                    // No profiles — show add server directly
                    Button {
                        showAddServer = true
                    } label: {
                        Label("Configurer un serveur", systemImage: "plus.circle")
                            .font(.headline)
                    }
                }

                // Cancel button (return to home if we have an active profile)
                if appState.profileManager.activeProfile != nil {
                    Button("Annuler") {
                        appState.hasActiveProfile = true
                    }
                    .foregroundColor(.white.opacity(0.4))
                }
            }
            .padding(60)
        }
        .fullScreenCover(isPresented: $showAddServer) {
            ServerSetupView()
        }
        .fullScreenCover(item: $pinProfile) { profile in
            PinEntryView(
                profileName: profile.name,
                pinHash: profile.pinHash ?? ""
            ) {
                pinProfile = nil
                activateProfile(profile)
            } onCancel: {
                pinProfile = nil
            }
        }
    }

    private func selectProfile(_ profile: Profile) {
        if profile.hasPin {
            pinProfile = profile
            return
        }
        activateProfile(profile)
    }

    private func activateProfile(_ profile: Profile) {
        appState.profileManager.setActive(profile)
        appState.api.configure(
            serverUrl: profile.serverUrl,
            username: profile.username,
            password: profile.password
        )
        appState.api.clearCache()
        Task {
            do {
                _ = try await appState.api.authenticate()
                if let uid = appState.authService.userId {
                    let hash = SupabaseConfig.profileHash(serverUrl: profile.serverUrl, username: profile.username)
                    appState.syncService.configure(profileHash: hash, userId: uid)
                    await appState.syncService.pullAll()
                }
                appState.hasActiveProfile = true
            } catch {
                appState.hasActiveProfile = true
            }
        }
    }
}
