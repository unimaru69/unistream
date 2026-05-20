import SwiftUI

/// Sheet that lets the signed-in user assign a real address to
/// their Supabase user without breaking their Apple Sign-In
/// identity. Mirrors Flutter's `_CrossDeviceCard`.
///
/// Why this exists: an iOS Apple Sign-In user with "Hide my email"
/// has a `@privaterelay.appleid.com` primary email. That address
/// can't receive magic-link OTPs on Mac, Linux or Windows. Their
/// favorites then stay isolated to the iOS user_id — invisible on
/// every other device. We let them swap the primary email to a
/// real one while keeping Apple Sign-In on tvOS / iOS untouched.
struct CrossDeviceEmailSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var isLoading = false
    @State private var error: String?
    @State private var confirmationSent = false

    var body: some View {
        ZStack {
            Color(hex: 0x0E0B1E).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 28) {
                // Header
                HStack {
                    Image(systemName: "rectangle.connected.to.line.below")
                        .font(.title2)
                        .foregroundColor(Color(hex: 0x1B6B8A))
                    Text("Synchronisation entre appareils")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }

                if confirmationSent {
                    confirmationView
                } else {
                    formView
                }

                Spacer()
            }
            .padding(60)
            .frame(maxWidth: 900)
        }
    }

    // MARK: - Views

    @ViewBuilder
    private var formView: some View {
        let currentEmail = appState.authService.currentUser?.email ?? ""
        let isPrivateRelay = currentEmail.hasSuffix("@privaterelay.appleid.com")

        VStack(alignment: .leading, spacing: 16) {
            // Explainer — calibrated to the most common foot-gun
            Text(isPrivateRelay
                ? "Tu utilises l'email masqué d'Apple (Hide My Email). Il ne peut PAS recevoir de lien magique sur Mac, Linux ou Windows — donc tes favoris ne se synchroniseront pas. Configure ici ton vrai email pour activer la synchro cross-device : ton Apple Sign-In sur tvOS et iOS continuera à fonctionner sans rien changer."
                : "L'email associé à ton compte sert d'identifiant cross-device. Pour que tes favoris, ta watchlist et ta progression remontent automatiquement sur tes autres appareils (iPhone, iPad, Mac, Linux), connecte-toi partout avec ce même email."
            )
            .font(.body)
            .foregroundColor(.white.opacity(0.85))

            // Current email read-only
            HStack(spacing: 12) {
                Image(systemName: "envelope")
                    .foregroundColor(.white.opacity(0.6))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Email actuel")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    Text(currentEmail.isEmpty ? "—" : currentEmail)
                        .font(.callout)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .padding(.vertical, 8)

            // New email input
            TextField("nouvel.email@exemple.com", text: $email)
                .textContentType(.emailAddress)
                .autocorrectionDisabled()

            if let error {
                Text(error)
                    .font(.callout)
                    .foregroundColor(.red)
            }

            HStack(spacing: 16) {
                Button("Annuler") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .disabled(isLoading)

                Button {
                    submit()
                } label: {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("Envoyer le lien de confirmation")
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: 0x1B6B8A))
                .disabled(isLoading || !isFormValid)
            }
        }
    }

    @ViewBuilder
    private var confirmationView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title)
                    .foregroundColor(.green)
                Text("Lien envoyé à \(email)")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            Text("Ouvre l'email et clique le lien pour confirmer le changement. Une fois validé, connecte-toi via lien magique avec ce nouvel email sur tes autres appareils — tes données seront déjà là.")
                .font(.body)
                .foregroundColor(.white.opacity(0.85))

            Button("Fermer") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: 0x1B6B8A))
            .padding(.top, 8)
        }
    }

    // MARK: - Validation + submit

    private var isFormValid: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains("@"), trimmed.contains(".") else { return false }
        guard trimmed != appState.authService.currentUser?.email else { return false }
        return true
    }

    private func submit() {
        Task {
            isLoading = true
            error = nil
            do {
                try await appState.authService.updateEmail(
                    email.trimmingCharacters(in: .whitespaces)
                )
                confirmationSent = true
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }
}
