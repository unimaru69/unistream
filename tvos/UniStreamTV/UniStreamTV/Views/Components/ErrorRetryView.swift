import SwiftUI

/// Reusable error + retry button with contextual icon.
struct ErrorRetryView: View {
    let error: String
    var icon: String = "exclamationmark.triangle"
    var onRetry: (() -> Void)?

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: errorIcon)
                .font(.system(size: 48))
                .foregroundColor(errorColor)

            Text(errorTitle)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text(error)
                .font(.body)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 500)

            if let onRetry {
                Button {
                    onRetry()
                } label: {
                    Label("Réessayer", systemImage: "arrow.clockwise")
                        .font(.headline)
                }
                .padding(.top, 8)
            }
        }
        .padding(40)
    }

    private var errorIcon: String {
        if error.localizedCaseInsensitiveContains("connexion") ||
           error.localizedCaseInsensitiveContains("network") ||
           error.localizedCaseInsensitiveContains("timeout") {
            return "wifi.slash"
        } else if error.localizedCaseInsensitiveContains("auth") ||
                  error.localizedCaseInsensitiveContains("401") ||
                  error.localizedCaseInsensitiveContains("password") {
            return "lock.shield"
        } else if error.localizedCaseInsensitiveContains("404") ||
                  error.localizedCaseInsensitiveContains("not found") {
            return "magnifyingglass"
        } else {
            return icon
        }
    }

    private var errorTitle: String {
        if errorIcon == "wifi.slash" { return "Problème de connexion" }
        if errorIcon == "lock.shield" { return "Erreur d'authentification" }
        if errorIcon == "magnifyingglass" { return "Contenu introuvable" }
        return "Une erreur est survenue"
    }

    private var errorColor: Color {
        if errorIcon == "wifi.slash" { return .orange }
        if errorIcon == "lock.shield" { return .red }
        return .yellow
    }
}
