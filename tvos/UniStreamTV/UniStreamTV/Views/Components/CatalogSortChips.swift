import SwiftUI

/// Sort options shared by `VODGridView` and `SeriesGridView`. The
/// "default" order is whatever the IPTV provider returns, which we
/// keep for users who scrolled the same shelf for years and rely on
/// muscle memory.
enum CatalogSortMode: String, CaseIterable, Identifiable {
    case `default`
    case recent
    case alphabetical
    case unwatched
    case inProgress

    var id: String { rawValue }

    var label: String {
        switch self {
        case .default: return "Défaut"
        case .recent: return "Récents"
        case .alphabetical: return "A-Z"
        case .unwatched: return "Non vus"
        case .inProgress: return "En cours"
        }
    }

    var iconSystemName: String {
        switch self {
        case .default: return "list.bullet"
        case .recent: return "clock.arrow.circlepath"
        case .alphabetical: return "textformat.abc"
        case .unwatched: return "circle"
        case .inProgress: return "play.circle"
        }
    }
}

/// Horizontal scroll of sort-mode chips. Same chip style as the
/// season picker on SeriesDetailView so the language is consistent.
struct CatalogSortChips: View {
    @Binding var selection: CatalogSortMode

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                ForEach(CatalogSortMode.allCases) { mode in
                    Button {
                        selection = mode
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: mode.iconSystemName)
                                .font(.caption)
                            Text(mode.label)
                        }
                    }
                    .buttonStyle(SortChipButtonStyle(isSelected: selection == mode))
                }
            }
        }
    }
}

private struct SortChipButtonStyle: ButtonStyle {
    let isSelected: Bool
    @Environment(\.isFocused) private var isFocused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.Typography.bodyEmphasised)
            .foregroundColor(textColor)
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.xs)
            .background(background)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : (isFocused ? DS.Focus.chipScale : 1.0))
            .animation(DS.Focus.animation, value: isFocused)
    }

    private var textColor: Color {
        if isFocused { return .black }
        return isSelected ? DS.Colour.textPrimary : DS.Colour.textSecondary
    }

    @ViewBuilder
    private var background: some View {
        if isFocused {
            Color.white
        } else if isSelected {
            DS.Colour.accent
        } else {
            Color.white.opacity(0.10)
        }
    }
}
