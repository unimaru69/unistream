import SwiftUI
import Kingfisher

/// Horizontal scroller of cast avatars — mirror of `TmdbCastRow` in
/// Flutter. Each avatar is now a deep-link into `CastFilmographyView`.
struct TMDBCastRow: View {
    let cast: [TMDBCast]

    @State private var openedCast: TMDBCast?

    @State private var lastFocusArrivedAt: Date = .distantPast
    @FocusState private var focusedId: Int?

    var body: some View {
        if cast.isEmpty {
            EmptyView()
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: DS.Spacing.lg) {
                    ForEach(cast) { c in
                        // focusable + onTapGesture (no system halo)
                        // with phantom-tap filter — same pattern as
                        // VLCVODOverlayView. The previous
                        // Button + buttonStyle(.plain) drew the
                        // wide grey halo the user explicitly didn't
                        // want around circular cast avatars.
                        CastAvatar(cast: c, isFocused: focusedId == c.id)
                            .focusable()
                            .focused($focusedId, equals: c.id)
                            .onTapGesture {
                                let elapsed = Date().timeIntervalSince(lastFocusArrivedAt)
                                guard elapsed > 0.25 else { return }
                                openedCast = c
                            }
                    }
                }
                .padding(.horizontal, DS.Padding.detailHorizontal)
            }
            .onChange(of: focusedId) { _, newValue in
                if newValue != nil {
                    lastFocusArrivedAt = Date()
                }
            }
            .fullScreenCover(item: $openedCast) { c in
                CastFilmographyView(
                    castMemberId: c.id,
                    initialName: c.name,
                    initialProfilePath: c.profilePath
                )
            }
        }
    }
}

/// Cast avatar — circular avatar with explicit accent ring on focus
/// (replacing the system halo we no longer get since this row uses
/// `focusable() + onTapGesture` instead of Button).
private struct CastAvatar: View {
    let cast: TMDBCast
    let isFocused: Bool

    var body: some View {
        VStack(spacing: DS.Spacing.xs) {
            ZStack {
                KFImage(cast.profileURL(size: "w185"))
                    .resizable()
                    .placeholder {
                        Circle()
                            .fill(DS.Colour.surface)
                            .overlay {
                                Image(systemName: "person.fill")
                                    .foregroundColor(DS.Colour.textTertiary)
                            }
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 110, height: 110)
                    .clipShape(Circle())
                // Accent ring on focus — same visual language as the
                // VOD drawer's transport buttons, just on a circle
                // instead of a rounded rect. Subtle scale + shadow
                // accompany it.
                Circle()
                    .strokeBorder(DS.Colour.accent, lineWidth: 4)
                    .frame(width: 110, height: 110)
                    .opacity(isFocused ? 1 : 0)
            }
            .scaleEffect(isFocused ? 1.06 : 1.0)
            .shadow(
                color: .black.opacity(isFocused ? DS.Focus.shadowOpacity : 0),
                radius: DS.Focus.shadowRadius,
                y: DS.Focus.shadowY
            )
            .animation(DS.Focus.animation, value: isFocused)

            Text(cast.name)
                .font(DS.Typography.caption)
                .fontWeight(.semibold)
                .foregroundColor(DS.Colour.textPrimary)
                .lineLimit(1)

            if !cast.character.isEmpty {
                Text(cast.character)
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colour.textTertiary)
                    .lineLimit(1)
            }
        }
        .frame(width: 140)
    }
}
