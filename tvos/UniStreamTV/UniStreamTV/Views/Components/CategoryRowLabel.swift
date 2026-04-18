import SwiftUI

/// Shared focus-aware sidebar row used by Live / Films / Séries split views.
/// Shows a leading SF Symbol, a title, an optional trailing count.
struct CategoryRowLabel: View {
    let icon: String
    let title: String
    var count: Int? = nil
    let isSelected: Bool

    @Environment(\.isFocused) private var isFocused

    private var accent: Color { Color(hex: 0x1B6B8A) }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(iconColor)
                .frame(width: 26)

            Text(title)
                .font(.body)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(textColor)
                .lineLimit(1)

            Spacer(minLength: 8)

            if let count {
                Text("\(count)")
                    .font(.caption)
                    .foregroundColor(textColor.opacity(0.6))
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 12)
        .scaleEffect(isFocused ? 1.04 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isFocused)
    }

    private var iconColor: Color {
        if isFocused { return .black }
        return isSelected ? accent : .secondary
    }

    private var textColor: Color {
        if isFocused { return .black }
        return isSelected ? .white : .white.opacity(0.75)
    }

    @ViewBuilder
    private var rowBackground: some View {
        if isFocused {
            Color.white
        } else if isSelected {
            accent.opacity(0.25)
        } else {
            Color.clear
        }
    }
}
