import SwiftUI

/// Custom button style for tvOS — provides focus feedback for buttons
/// that wrap a `FocusableCardLabel` (or any card-shaped label).
///
/// Important: scale + shadow are intentionally **not** applied here.
/// `FocusableCardLabel` reads `\.isFocused` itself and scales only its
/// image; the surrounding title block stays static. If we re-applied a
/// scale at the button level it would compound (1.08 × 1.10 ≈ 1.19) and
/// the title would still get pushed around. We keep this style purely
/// for the press-down feedback + a subtle press scale.
struct TVCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(DS.Focus.animation, value: configuration.isPressed)
    }
}

/// Subtle style for list rows and text buttons.
struct TVRowButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isFocused ? Color(hex: 0x1B6B8A).opacity(0.3) : Color.clear)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isFocused)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == TVCardButtonStyle {
    static var tvCard: TVCardButtonStyle { TVCardButtonStyle() }
}

extension ButtonStyle where Self == TVRowButtonStyle {
    static var tvRow: TVRowButtonStyle { TVRowButtonStyle() }
}
