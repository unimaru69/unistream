import SwiftUI

/// Tiny pill that tags content as coming from TMDB — required by TMDB's
/// attribution guidelines and useful for user transparency.
struct TMDBBadge: View {
    var label: String = "via TMDB"

    var body: some View {
        Text(label)
            .font(.caption2.weight(.semibold))
            .foregroundColor(.white.opacity(0.75))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.white.opacity(0.12), in: Capsule())
    }
}
