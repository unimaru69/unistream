import SwiftUI

/// IPTV server credentials setup screen.
struct ServerSetupView: View {
    @Environment(AppState.self) private var appState
    @State private var name = ""
    @State private var serverUrl = ""
    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        ZStack {
            Color(hex: 0x0E0B1E).ignoresSafeArea()

            VStack(spacing: 40) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 50))
                        .foregroundColor(Color(hex: 0x1B6B8A))

                    Text("Configurer votre serveur")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("Entrez les identifiants de votre fournisseur IPTV")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }

                // Form
                VStack(spacing: 20) {
                    TextField("Nom du profil", text: $name)

                    TextField("URL du serveur", text: $serverUrl)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()

                    TextField("Nom d'utilisateur", text: $username)
                        .autocorrectionDisabled()

                    SecureField("Mot de passe", text: $password)

                    Button(action: connect) {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("Connecter")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(serverUrl.isEmpty || username.isEmpty || password.isEmpty || isLoading)
                }
                .frame(maxWidth: 500)

                if let error {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.callout)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(60)
        }
    }

    private func connect() {
        Task {
            isLoading = true
            error = nil

            let profileName = name.isEmpty ? username : name
            let profile = Profile(
                name: profileName,
                serverUrl: serverUrl.trimmingCharacters(in: .whitespacesAndNewlines),
                username: username.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            )

            // Test connection
            appState.api.configure(
                serverUrl: profile.serverUrl,
                username: profile.username,
                password: profile.password
            )

            do {
                _ = try await appState.api.authenticate()
                // Save and activate profile
                appState.profileManager.addProfile(profile)
                appState.profileManager.setActive(profile)
                // Claim profile data in background (don't block)
                Task { await appState.authService.claimProfileData(profileHash: profile.profileHash) }
                // Transition to home
                appState.onServerConfigured()
            } catch {
                self.error = error.localizedDescription
            }

            isLoading = false
        }
    }
}
