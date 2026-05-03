import SwiftUI
import Kingfisher

/// Plex-style blurred backdrop for detail views.
/// Full-screen poster image, heavily blurred, with dark gradient overlay for readability.
struct PlexBackdrop: View {
    let imageUrl: String
    /// Tint colour pulled from the brand palette — blended into the darkening overlay.
    var tint: Color = DS.Colour.accent
    /// Blur radius. Higher = softer, less detail.
    /// 28 keeps the image legible (you can still "see" the poster) while
    /// staying soft enough that the foreground text remains readable.
    var blurRadius: CGFloat = 28
    /// When true (default), the backdrop fills past safe-area insets —
    /// suitable for full-screen detail views (SeriesDetailView etc).
    /// Set to false when the backdrop lives inside a contained pane (a
    /// split-view's right column) so it doesn't leak across the sidebar.
    var ignoresSafeArea: Bool = true

    var body: some View {
        ZStack {
            // Base dark fill so we never get a light flash while the image loads.
            DS.Colour.background
                .applyingIgnoreSafeArea(ignoresSafeArea)

            // Backdrop image — blurred & scaled to kill hard edges.
            KFImage(URL(string: imageUrl))
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .blur(radius: blurRadius, opaque: true)
                .scaleEffect(1.15)
                .opacity(0.85)
                .applyingIgnoreSafeArea(ignoresSafeArea)

            // Darkening gradient — deeper on the leading edge where text lives,
            // lighter on the trailing edge so the image is still visible.
            LinearGradient(
                colors: [
                    DS.Colour.background.opacity(0.85),
                    DS.Colour.background.opacity(0.55),
                    DS.Colour.background.opacity(0.35),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .applyingIgnoreSafeArea(ignoresSafeArea)

            // Subtle brand tint washed in from the top-left (keeps Plex feel but stays on-brand).
            RadialGradient(
                colors: [tint.opacity(0.22), .clear],
                center: .topLeading,
                startRadius: 100,
                endRadius: 1200
            )
            .applyingIgnoreSafeArea(ignoresSafeArea)

            // Bottom vignette so the list area fades into darkness.
            LinearGradient(
                colors: [.clear, DS.Colour.background.opacity(0.85)],
                startPoint: .center,
                endPoint: .bottom
            )
            .applyingIgnoreSafeArea(ignoresSafeArea)
        }
        .clipped()
    }
}

private extension View {
    @ViewBuilder
    func applyingIgnoreSafeArea(_ apply: Bool) -> some View {
        if apply { self.ignoresSafeArea() } else { self }
    }
}
