import SwiftUI
import Kingfisher

/// Visual card label — used inside NavigationLink or Button.
/// Does NOT wrap in a Button itself; the parent provides the interactive
/// wrapper.
///
/// Two layout invariants the rest of the app depends on:
/// 1. Only the **image** scales on focus, the title block stays static —
///    so a scaling card never overlaps its own title nor pushes
///    siblings around.
/// 2. The title block reserves the height of two lines, even if the
///    title fits on one. Cards across a row therefore stay aligned to
///    the same baseline regardless of how long each title is.
struct FocusableCardLabel: View {
    let title: String
    let imageUrl: String
    var hasBadge: Bool = false
    var aspectRatio: CGFloat = 16/9
    var subtitle: String? = nil
    var channelNumber: Int? = nil
    var isFavorite: Bool = false
    var isLive: Bool = false

    @Environment(\.isFocused) private var isFocused

    /// Height reserved for the title block — sized for two lines of
    /// `DS.Typography.title3` (20pt × ~1.25 line-height ≈ 25 → 50 for
    /// 2 lines). A subtitle adds another single-line slot.
    private var titleHeight: CGFloat { 54 }
    private var subtitleHeight: CGFloat { 22 }

    private var imageHeight: CGFloat { aspectRatio < 1 ? 240 : 120 }

    var body: some View {
        VStack(alignment: .center, spacing: DS.Spacing.sm) {
            // Image / artwork: this is the only piece that scales on
            // focus — keeps the title baseline rock-steady so cards
            // never appear to "wobble" as the user moves across the
            // row.
            imageContainer
                .scaleEffect(isFocused ? DS.Focus.cardScale : 1.0)
                .shadow(
                    color: .black.opacity(isFocused ? DS.Focus.shadowOpacity : 0),
                    radius: DS.Focus.shadowRadius,
                    y: DS.Focus.shadowY
                )
                .animation(DS.Focus.animation, value: isFocused)

            VStack(alignment: .center, spacing: 2) {
                Text(title)
                    .font(DS.Typography.title3)
                    .foregroundColor(DS.Colour.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(height: titleHeight, alignment: .top)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colour.textTertiary)
                        .lineLimit(1)
                        .frame(height: subtitleHeight, alignment: .top)
                }
            }
            // Title block stays put on focus. Padding above gives the
            // scaled image its 10% breathing room without shifting the
            // baseline.
        }
        // Reserve enough headroom around the image for the focused
        // scale (~10%) so neighbours' titles aren't clipped by the
        // ScrollView's clipping bounds.
        .padding(.top, DS.Spacing.xs)
        .padding(.bottom, DS.Spacing.xs)
    }

    private var imageContainer: some View {
        ZStack {
            if let url = URL(string: imageUrl), !imageUrl.isEmpty {
                KFImage(url)
                    .placeholder { cardPlaceholder }
                    .resizable()
                    .aspectRatio(aspectRatio, contentMode: .fill)
                    .frame(height: imageHeight)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
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
                            .foregroundColor(DS.Colour.textPrimary)
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
                                .foregroundColor(DS.Colour.warning)
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
                            .foregroundColor(DS.Colour.textPrimary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(DS.Colour.accentWarm, in: RoundedRectangle(cornerRadius: 4))
                        Spacer()
                    }
                }
                .padding(6)
            }
        }
    }

    private var cardPlaceholder: some View {
        RoundedRectangle(cornerRadius: DS.Radius.card)
            .fill(DS.Colour.surface)
            .frame(height: imageHeight)
            .overlay {
                Image(systemName: aspectRatio < 1 ? "film" : "tv")
                    .font(.title)
                    .foregroundColor(DS.Colour.textTertiary)
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
