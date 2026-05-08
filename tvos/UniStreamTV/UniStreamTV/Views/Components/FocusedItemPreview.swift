import SwiftUI
import Kingfisher

/// Bottom-of-grid preview that surfaces TMDB metadata for the
/// currently-focused card. Apple TV+-style: titre + note + année +
/// synopsis + cast peek. Animates in when an item is focused, slides
/// out when focus leaves the grid.
///
/// Used by `VODGridView` and `SeriesGridView`. The TMDB lookup is
/// debounced so rapid focus moves across the grid don't spam the
/// network.
struct FocusedItemPreview: View {
    /// Title used to drive the TMDB lookup.
    let rawTitle: String
    /// Cover URL — already known locally, no need to wait for TMDB.
    let coverUrl: String
    /// Provider rating, used as a fallback when TMDB hasn't returned.
    let providerRating: String?
    let kind: TMDBKind

    @State private var tmdbVM = TMDBViewModel()

    private var year: String {
        if let y = tmdbVM.result?.year { return "\(y)" }
        return ""
    }
    private var rating: String {
        let tmdb = formattedRating(tmdbVM.result?.rating)
        if !tmdb.isEmpty { return tmdb }
        if let r = providerRating, !r.isEmpty, r != "0" { return r }
        return ""
    }
    private var synopsis: String {
        tmdbVM.result?.overview ?? ""
    }

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.lg) {
            cover
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text(rawTitle.cleanedTitleNoYear)
                    .font(DS.Typography.title2)
                    .foregroundColor(DS.Colour.textPrimary)
                    .lineLimit(1)

                metadataStrip

                if !synopsis.isEmpty {
                    Text(synopsis)
                        .font(DS.Typography.body)
                        .foregroundColor(DS.Colour.textSecondary)
                        .lineLimit(3)
                } else if tmdbVM.isLoading {
                    Text("Chargement de la synopsis…")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colour.textTertiary)
                } else {
                    // Empty state — keep the strip the same height so the
                    // grid above doesn't shift when the preview swaps in.
                    Color.clear.frame(height: 60)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .padding(.horizontal, DS.Padding.screenHorizontal)
        .padding(.vertical, DS.Spacing.md)
        .background(
            LinearGradient(
                colors: [
                    DS.Colour.background.opacity(0.0),
                    DS.Colour.background.opacity(0.9),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .task(id: rawTitle) {
            await tmdbVM.load(rawTitle: rawTitle, kind: kind)
        }
    }

    private var cover: some View {
        KFImage(URL(string: coverUrl))
            .resizable()
            .placeholder {
                RoundedRectangle(cornerRadius: DS.Radius.card)
                    .fill(DS.Colour.surface)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 80, height: 120)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
    }

    @ViewBuilder
    private var metadataStrip: some View {
        HStack(spacing: DS.Spacing.sm) {
            if !rating.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundColor(DS.Colour.warning)
                    Text(rating)
                }
            }
            if !year.isEmpty {
                if !rating.isEmpty {
                    Text("·").foregroundColor(DS.Colour.textTertiary)
                }
                Text(year)
            }
        }
        .font(DS.Typography.bodyEmphasised)
        .foregroundColor(DS.Colour.textSecondary)
    }
}
