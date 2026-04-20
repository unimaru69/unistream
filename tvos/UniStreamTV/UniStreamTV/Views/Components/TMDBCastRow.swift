import SwiftUI
import Kingfisher

/// Horizontal scroller of cast avatars — mirror of `TmdbCastRow` in Flutter.
struct TMDBCastRow: View {
    let cast: [TMDBCast]

    var body: some View {
        if cast.isEmpty {
            EmptyView()
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 24) {
                    ForEach(cast) { c in
                        VStack(spacing: 8) {
                            KFImage(c.profileURL(size: "w185"))
                                .resizable()
                                .placeholder {
                                    Circle()
                                        .fill(DS.Colour.surface)
                                        .overlay {
                                            Image(systemName: "person.fill")
                                                .foregroundColor(.white.opacity(0.35))
                                        }
                                }
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 110, height: 110)
                                .clipShape(Circle())
                            Text(c.name)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .lineLimit(1)
                            if !c.character.isEmpty {
                                Text(c.character)
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.65))
                                    .lineLimit(1)
                            }
                        }
                        .frame(width: 140)
                    }
                }
                .padding(.horizontal, 40)
            }
        }
    }
}
