import SwiftUI

/// Reusable empty-state placeholder for grids and lists.
/// Usage:
///   EmptyStateView(
///       icon: "heart",
///       title: "Aucun favori",
///       description: "Ajoute du contenu…",
///       actionLabel: "Parcourir",
///       action: { … }
///   )
struct EmptyStateView: View {
    let icon: String
    let title: String
    var description: String? = nil
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.5))

            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            if let description {
                Text(description)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 640)
            }

            if let actionLabel, let action {
                Button(action: action) {
                    Text(actionLabel)
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .tint(Color(hex: 0x1B6B8A))
                .padding(.top, 8)
            }
        }
        .padding(60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
