import SwiftUI

/// Custom button style for tvOS — provides clear focus feedback with scale + glow.
/// Use on all interactive elements that use `.buttonStyle(.plain)`.
struct TVCardButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(isFocused ? 1.08 : (configuration.isPressed ? 0.95 : 1.0))
            .brightness(isFocused ? 0.1 : 0)
            .shadow(color: isFocused ? Color(hex: 0x1B6B8A).opacity(0.6) : .clear, radius: 12, y: 8)
            .animation(.easeInOut(duration: 0.15), value: isFocused)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
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
