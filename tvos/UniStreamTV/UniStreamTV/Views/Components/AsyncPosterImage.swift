import SwiftUI
import Kingfisher

/// Async poster image (2:3 aspect ratio) with placeholder.
struct AsyncPosterImage: View {
    let url: String

    var body: some View {
        if let imageUrl = URL(string: url), !url.isEmpty {
            KFImage(imageUrl)
                .resizable()
                .placeholder {
                    posterPlaceholder
                }
                .aspectRatio(2/3, contentMode: .fill)
                .frame(width: 160, height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            posterPlaceholder
        }
    }

    private var posterPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(hex: 0x161230))
            .frame(width: 160, height: 240)
            .overlay {
                Image(systemName: "film")
                    .font(.title)
                    .foregroundColor(.white.opacity(0.3))
            }
    }
}
