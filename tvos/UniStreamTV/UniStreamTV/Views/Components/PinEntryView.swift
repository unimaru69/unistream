import SwiftUI
import CryptoKit

/// Reusable PIN entry sheet for profile-level PIN verification.
///
/// Displays a secure text field and verifies the entered PIN against
/// the profile's `pinHash` (SHA-256). Calls `onSuccess` when correct,
/// `onCancel` when dismissed.
struct PinEntryView: View {
    let profileName: String
    let pinHash: String
    let onSuccess: () -> Void
    let onCancel: () -> Void

    @State private var pin = ""
    @State private var error = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // Icon + title
            VStack(spacing: 16) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 48))
                    .foregroundColor(Color(hex: 0x1B6B8A))

                Text("Profil protégé")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("Entrez le code PIN pour « \(profileName) »")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }

            // PIN field
            VStack(spacing: 12) {
                SecureField("Code PIN", text: $pin)
                    .keyboardType(.numberPad)
                    .focused($isFocused)
                    .frame(maxWidth: 300)
                    .onSubmit { verify() }

                if error {
                    Text("Code PIN incorrect")
                        .font(.callout)
                        .foregroundColor(.red)
                }
            }

            // Buttons
            HStack(spacing: 32) {
                Button("Annuler") {
                    onCancel()
                }
                .foregroundColor(.white.opacity(0.5))

                Button("Valider") {
                    verify()
                }
                .disabled(pin.isEmpty)
            }

            Spacer()
        }
        .padding(60)
        .background(
            LinearGradient(
                colors: [Color(hex: 0x0E0B1E), Color(hex: 0x161230)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .onAppear { isFocused = true }
    }

    private func verify() {
        let hash = SHA256.hash(data: Data(pin.utf8))
            .map { String(format: "%02x", $0) }
            .joined()

        if hash == pinHash {
            onSuccess()
        } else {
            error = true
            pin = ""
        }
    }
}
