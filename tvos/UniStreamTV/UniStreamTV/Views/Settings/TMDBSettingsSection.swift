import SwiftUI

/// Settings block for the TMDB enrichment feature. Parity with the
/// `TmdbSection` widget in the Flutter app.
struct TMDBSettingsSection: View {
    @Bindable private var config = TMDBConfig.shared
    @State private var draftKey: String = ""
    @State private var hasLoadedDraft = false

    var body: some View {
        Section {
            Toggle(isOn: $config.enabled) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enrichir avec TMDB")
                        Text(statusText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } icon: {
                    Image(systemName: "sparkles")
                }
            }

            // Key entry — SecureField on tvOS uses the system overlay
            // keyboard, which is the right UX for a long secret.
            SecureField("Clé TMDB v3", text: $draftKey)
                .onAppear {
                    if !hasLoadedDraft {
                        draftKey = config.apiKey
                        hasLoadedDraft = true
                    }
                }

            if draftKey != config.apiKey {
                Button {
                    config.apiKey = draftKey.trimmingCharacters(in: .whitespacesAndNewlines)
                } label: {
                    Label("Enregistrer la clé", systemImage: "checkmark.circle.fill")
                }
                .tint(.green)
            }

            Text(
                "Enrichit les films et séries sans synopsis avec les infos " +
                "de The Movie Database : synopsis FR, arrière-plan cinémascope, " +
                "distribution, bandes-annonces. Créez une clé gratuite sur " +
                "themoviedb.org/settings/api."
            )
            .font(.footnote)
            .foregroundColor(.secondary)
        } header: {
            Text("Métadonnées TMDB")
        }
    }

    private var statusText: String {
        if config.apiKey.isEmpty {
            return "Clé manquante — TMDB dormant."
        }
        return config.enabled
            ? "TMDB actif : synopsis, arrière-plan, casting, trailers."
            : "Désactivé par l'utilisateur."
    }
}
