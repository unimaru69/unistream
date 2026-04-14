import SwiftUI
import Kingfisher

/// Visual card label — used inside NavigationLink or Button.
/// Does NOT wrap in a Button itself; the parent provides the interactive wrapper.
struct FocusableCardLabel: View {
    let title: String
    let imageUrl: String
    var hasBadge: Bool = false
    var aspectRatio: CGFloat = 16/9
    var subtitle: String? = nil
    var channelNumber: Int? = nil
    var isFavorite: Bool = false
    var isLive: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                if let url = URL(string: imageUrl), !imageUrl.isEmpty {
                    KFImage(url)
                        .placeholder {
                            cardPlaceholder
                        }
                        .resizable()
                        .aspectRatio(aspectRatio, contentMode: .fill)
                        .frame(height: aspectRatio < 1 ? 240 : 120)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    cardPlaceholder
                }

                // Top-left: channel number badge
                if let num = channelNumber {
                    VStack {
                        HStack {
                            Text("\(num)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 6))
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(6)
                }

                // Top-right badges
                VStack {
                    HStack {
                        Spacer()
                        HStack(spacing: 4) {
                            if isFavorite {
                                Image(systemName: "heart.fill")
                                    .font(.caption2)
                                    .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
                                    .padding(4)
                                    .background(.ultraThinMaterial, in: Circle())
                            }
                            if hasBadge {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.caption2)
                                    .padding(4)
                                    .background(.ultraThinMaterial, in: Circle())
                            }
                        }
                    }
                    Spacer()
                }
                .padding(6)

                // Bottom-left: live badge
                if isLive {
                    VStack {
                        Spacer()
                        HStack {
                            Text("EN DIRECT")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.red, in: RoundedRectangle(cornerRadius: 4))
                            Spacer()
                        }
                    }
                    .padding(6)
                }
            }

            Text(title)
                .font(.caption)
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
            }
        }
    }

    private var cardPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(hex: 0x161230))
            .frame(height: aspectRatio < 1 ? 240 : 120)
            .overlay {
                Image(systemName: aspectRatio < 1 ? "film" : "tv")
                    .font(.title)
                    .foregroundColor(.white.opacity(0.3))
            }
    }
}

/// Convenience wrapper — a Button containing a FocusableCardLabel.
/// Use when you need a tap action instead of navigation.
struct FocusableCard: View {
    let title: String
    let imageUrl: String
    var hasBadge: Bool = false
    var aspectRatio: CGFloat = 16/9
    var subtitle: String? = nil
    var channelNumber: Int? = nil
    var isFavorite: Bool = false
    var isLive: Bool = false
    var onSelect: () -> Void = {}

    var body: some View {
        Button(action: onSelect) {
            FocusableCardLabel(
                title: title,
                imageUrl: imageUrl,
                hasBadge: hasBadge,
                aspectRatio: aspectRatio,
                subtitle: subtitle,
                channelNumber: channelNumber,
                isFavorite: isFavorite,
                isLive: isLive
            )
        }
        .buttonStyle(.tvCard)
    }
}
