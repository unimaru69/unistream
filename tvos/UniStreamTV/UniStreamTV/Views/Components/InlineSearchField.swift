import SwiftUI

/// Compact inline search trigger for grid views — lives next to the
/// sort chips and stays out of the way until activated.
///
/// The default `.searchable` modifier pushes a full-width search bar
/// over the page header, which dominates the top third of the screen
/// on tvOS. This component renders as a single magnifier-icon button
/// that, when pressed, opens a focused sheet with a TextField + the
/// on-screen keyboard. Search query lives in a `@Binding` so the
/// parent grid can filter as it changes.
struct InlineSearchField: View {
    @Binding var query: String
    /// Placeholder shown both inside the trigger button when the
    /// query is empty and inside the sheet's text field.
    let placeholder: String

    @State private var sheetPresented = false

    var body: some View {
        Button {
            sheetPresented = true
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                if query.isEmpty {
                    Text("Rechercher")
                } else {
                    // Show the current query as a chip-like preview so
                    // the user knows the grid below is filtered.
                    Text("« \(query) »")
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(SearchTriggerButtonStyle(isActive: !query.isEmpty))
        .sheet(isPresented: $sheetPresented) {
            SearchSheet(query: $query, placeholder: placeholder, onClose: {
                sheetPresented = false
            })
        }
    }
}

private struct SearchTriggerButtonStyle: ButtonStyle {
    let isActive: Bool
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
        return isActive ? DS.Colour.textPrimary : DS.Colour.textSecondary
    }

    @ViewBuilder
    private var background: some View {
        if isFocused {
            Color.white
        } else if isActive {
            DS.Colour.accent
        } else {
            Color.white.opacity(0.10)
        }
    }
}

/// Modal search sheet — TextField + clear / close actions. The on-
/// screen keyboard fills the lower half of the screen as soon as the
/// field is focused.
private struct SearchSheet: View {
    @Binding var query: String
    let placeholder: String
    let onClose: () -> Void

    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(spacing: DS.Spacing.xl) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "magnifyingglass")
                    .font(.title2)
                    .foregroundColor(DS.Colour.textSecondary)
                TextField(placeholder, text: $query)
                    .font(DS.Typography.title2)
                    .focused($fieldFocused)
                    .textFieldStyle(.plain)
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(DS.Colour.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.vertical, DS.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.hero)
                    .fill(DS.Colour.surfaceElevated)
            )

            Button {
                onClose()
            } label: {
                Text("Fermer")
                    .font(DS.Typography.bodyEmphasised)
                    .padding(.horizontal, DS.Spacing.xl)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(Color.white.opacity(0.10), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(DS.Spacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.Colour.background.opacity(0.95).ignoresSafeArea())
        .onAppear { fieldFocused = true }
    }
}
