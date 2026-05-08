import SwiftUI
import Kingfisher

/// Horizontal scroller of cast avatars — mirror of `TmdbCastRow` in
/// Flutter. Each avatar is now a deep-link into `CastFilmographyView`.
struct TMDBCastRow: View {
    let cast: [TMDBCast]

    @State private var openedCast: TMDBCast?

    var body: some View {
        if cast.isEmpty {
            EmptyView()
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: DS.Spacing.lg) {
                    ForEach(cast) { c in
                        // Wrap each cast item in a focusable Button so
                        // the tvOS focus engine treats the row as
                        // reachable territory — without this the parent
                        // vertical ScrollView never scrolls down to the
                        // row (no focusable element below the action
                        // buttons), which is why the row used to clip
                        // at the bottom of the screen on long detail
                        // views.
                        Button {
                            openedCast = c
                        } label: {
                            CastAvatar(cast: c)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DS.Padding.detailHorizontal)
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

/// Cast avatar — image-only focus scale (matches the home shelf cards
/// pattern); name + character stay fixed below to avoid clipping.
private struct CastAvatar: View {
    let cast: TMDBCast
    @Environment(\.isFocused) private var isFocused

    var body: some View {
        VStack(spacing: DS.Spacing.xs) {
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
                .scaleEffect(isFocused ? DS.Focus.cardScale : 1.0)
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
