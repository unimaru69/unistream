import SwiftUI

/// Primary call-to-action used in detail-view hero blocks
/// (VODDetailView, SeriesDetailView). Pill-shaped, accent fill by
/// default, white-on-black on focus — same focus inversion as the
/// home hero CTA so the language stays consistent.
///
/// Visual size is intentionally larger than `.bordered` so this button
/// reads as the "what to do next" choice without the user having to
/// scan among equal-weight buttons.
struct PrimaryHeroButton: ButtonStyle {
    @Environment(\.isFocused) private var isFocused
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.Typography.bodyEmphasised)
            .foregroundColor(isFocused ? .black : DS.Colour.textPrimary)
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.vertical, DS.Spacing.sm)
            .background(
                isFocused
                ? AnyShapeStyle(Color.white)
                : AnyShapeStyle(DS.Colour.accent)
            )
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : (isFocused ? 1.06 : 1.0))
            .shadow(
                color: .black.opacity(isFocused ? 0.45 : 0),
                radius: 18,
                y: 8
            )
            .animation(DS.Focus.animation, value: isFocused)
    }
}

/// Secondary action — translucent fill, lifts on focus. Holds an
/// optional `activeTint` that takes over when the action is in its
/// "on" state (heart filled / bookmark filled / etc.) so the user
/// can see at a glance what's already toggled.
struct GhostHeroButton: ButtonStyle {
    @Environment(\.isFocused) private var isFocused
    /// Colour used when `isActive` is true. Falls back to accent.
    var activeTint: Color = DS.Colour.accent
    /// Toggle-state hint — passes through from the call-site so the
    /// chip can render filled when the user has already favourited /
    /// watchlisted / etc.
    var isActive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        let baseFill: AnyShapeStyle = isActive
            ? AnyShapeStyle(activeTint.opacity(0.85))
            : AnyShapeStyle(Color.white.opacity(0.10))

        return configuration.label
            .font(DS.Typography.bodyEmphasised)
            .foregroundColor(isFocused ? .black : DS.Colour.textPrimary)
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.sm)
            .background(
                isFocused
                ? AnyShapeStyle(Color.white)
                : baseFill
            )
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : (isFocused ? 1.05 : 1.0))
            .animation(DS.Focus.animation, value: isFocused)
    }
}
