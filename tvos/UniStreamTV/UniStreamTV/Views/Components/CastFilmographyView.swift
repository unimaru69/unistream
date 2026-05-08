import SwiftUI
import Kingfisher

/// Filmography page opened by tapping a cast member in `TMDBCastRow`.
///
/// Layout:
///   - Header: portrait + name + bio
///   - Section "Films" : grid of TMDB credits
///   - Section "Séries" : grid of TMDB credits
///
/// Each credit card resolves against the local Xtream catalog via
/// `CatalogIndex`. Matches open the corresponding Detail view; non-
/// matches render disabled with a "Pas dans votre catalogue" hint.
struct CastFilmographyView: View {
    let castMemberId: Int
    /// Pre-rendered name to show before TMDB details land.
    let initialName: String
    let initialProfilePath: String?

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var details: TMDBPersonDetails?
    @State private var movies: [TMDBPersonCredit] = []
    @State private var tvShows: [TMDBPersonCredit] = []
    @State private var isLoading = true
    @State private var presentedVod: VodItem?
    @State private var presentedSeries: SeriesItem?
    @State private var notFoundAlert = false

    private let posterColumns = [GridItem(.adaptive(minimum: 200, maximum: 240), spacing: DS.Spacing.lg)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
                header
                if isLoading && movies.isEmpty && tvShows.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView().tint(DS.Colour.textPrimary)
                        Spacer()
                    }
                    .padding(.top, DS.Spacing.xxl)
                } else {
                    if !movies.isEmpty {
                        creditSection(title: "Films", credits: movies, kind: .movie)
                    }
                    if !tvShows.isEmpty {
                        creditSection(title: "Séries", credits: tvShows, kind: .tv)
                    }
                }
            }
            .padding(.horizontal, DS.Padding.screenHorizontal)
            .padding(.vertical, DS.Padding.sectionGap)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.Colour.background.ignoresSafeArea())
        .ignoresSafeArea(edges: .top)
        .task(id: castMemberId) { await load() }
        .fullScreenCover(item: $presentedVod) { vod in
            VODDetailView(item: vod, api: appState.api)
        }
        .fullScreenCover(item: $presentedSeries) { series in
            if let seriesVM = appState.seriesVM {
                SeriesDetailView(series: series, viewModel: seriesVM, api: appState.api)
            }
        }
        .alert("Pas dans votre catalogue", isPresented: $notFoundAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Ce titre n'est pas disponible chez votre fournisseur Xtream.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: DS.Spacing.xl) {
            portrait
                .frame(width: 220, height: 220)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.4), radius: 18, y: 8)

            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text(details?.name ?? initialName)
                    .font(DS.Typography.display)
                    .foregroundColor(DS.Colour.textPrimary)
                    .lineLimit(2)

                if let dept = details?.knownForDepartment, !dept.isEmpty {
                    Text(dept)
                        .font(DS.Typography.bodyEmphasised)
                        .foregroundColor(DS.Colour.accentLight)
                }

                if let bio = details?.biography, !bio.isEmpty {
                    Text(bio)
                        .font(DS.Typography.body)
                        .foregroundColor(DS.Colour.textSecondary)
                        .lineLimit(6)
                        .frame(maxWidth: 1100, alignment: .leading)
                }

                TMDBBadge()
            }

            Spacer()
        }
    }

    @ViewBuilder
    private var portrait: some View {
        let url = details?.profileURL() ?? TMDBService.imageURL(path: initialProfilePath, size: "h632")
        if let url {
            KFImage(url)
                .resizable()
                .placeholder { portraitPlaceholder }
                .aspectRatio(contentMode: .fill)
        } else {
            portraitPlaceholder
        }
    }

    private var portraitPlaceholder: some View {
        ZStack {
            Circle().fill(DS.Colour.surface)
            Image(systemName: "person.fill")
                .font(.system(size: 80, weight: .light))
                .foregroundColor(DS.Colour.textTertiary)
        }
    }

    // MARK: - Credit sections

    @ViewBuilder
    private func creditSection(title: String, credits: [TMDBPersonCredit], kind: TMDBKind) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.sm) {
                Text(title)
                    .font(DS.Typography.title1)
                    .foregroundColor(DS.Colour.textPrimary)
                Text("\(credits.count)")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colour.textTertiary)
                Spacer()
                // Surface index-warmup state so the user understands
                // why some cards are disabled while we're still
                // pulling the full catalogue from Xtream.
                indexHint(for: kind)
            }

            LazyVGrid(columns: posterColumns, spacing: DS.Spacing.lg) {
                ForEach(credits) { credit in
                    creditCard(for: credit)
                }
            }
        }
    }

    @ViewBuilder
    private func indexHint(for kind: TMDBKind) -> some View {
        let state = (kind == .movie) ? appState.catalogIndex.movieState : appState.catalogIndex.seriesState
        switch state {
        case .loading:
            HStack(spacing: 6) {
                ProgressView().tint(DS.Colour.textTertiary)
                Text("Indexation du catalogue…")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colour.textTertiary)
            }
        default:
            EmptyView()
        }
    }

    private func creditCard(for credit: TMDBPersonCredit) -> some View {
        let match = appState.catalogIndex.match(title: credit.title, kind: credit.mediaType)
        let isAvailable: Bool
        switch match {
        case .vod, .series: isAvailable = true
        case .notFound: isAvailable = false
        }

        return Button {
            switch match {
            case .vod(let v): presentedVod = v
            case .series(let s): presentedSeries = s
            case .notFound: notFoundAlert = true
            }
        } label: {
            CreditCardLabel(credit: credit, isAvailable: isAvailable)
        }
        .buttonStyle(.tvCard)
    }

    // MARK: - Loaders

    private func load() async {
        // Warm up both catalog indexes in parallel — the user might
        // tap any film or series, and pre-loading both removes the
        // "Indexation…" delay on first interaction.
        appState.catalogIndex.warmupIfNeeded(.movie)
        appState.catalogIndex.warmupIfNeeded(.tv)

        async let detailsAsync = TMDBService.shared.fetchPersonDetails(id: castMemberId)
        async let creditsAsync = TMDBService.shared.fetchPersonCredits(id: castMemberId)

        let fetchedDetails = await detailsAsync
        let (fetchedMovies, fetchedTV) = await creditsAsync

        details = fetchedDetails
        movies = fetchedMovies
        tvShows = fetchedTV
        isLoading = false
    }
}

// MARK: - Credit card label

private struct CreditCardLabel: View {
    let credit: TMDBPersonCredit
    let isAvailable: Bool

    @Environment(\.isFocused) private var isFocused

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            poster
                .scaleEffect(isFocused ? DS.Focus.cardScale : 1.0)
                .shadow(
                    color: .black.opacity(isFocused ? DS.Focus.shadowOpacity : 0),
                    radius: DS.Focus.shadowRadius,
                    y: DS.Focus.shadowY
                )
                .animation(DS.Focus.animation, value: isFocused)

            Text(credit.title.cleanedTitleNoYear)
                .font(DS.Typography.title3)
                .foregroundColor(isAvailable ? DS.Colour.textPrimary : DS.Colour.textTertiary)
                .lineLimit(1)

            HStack(spacing: 4) {
                if let y = credit.year {
                    Text("\(y)")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colour.textTertiary)
                }
                if let role = credit.character, !role.isEmpty {
                    Text("·")
                        .foregroundColor(DS.Colour.textTertiary)
                    Text(role)
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colour.textTertiary)
                        .lineLimit(1)
                }
            }
        }
        .frame(width: 200)
    }

    @ViewBuilder
    private var poster: some View {
        ZStack(alignment: .bottomLeading) {
            if let url = credit.posterURL() {
                KFImage(url)
                    .resizable()
                    .placeholder { posterPlaceholder }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 200, height: 300)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
            } else {
                posterPlaceholder
                    .frame(width: 200, height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
            }

            // Greyscale wash + "Pas dans votre catalogue" hint when
            // the title isn't available locally.
            if !isAvailable {
                Color.black.opacity(0.55)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
                Text("Pas dans votre\ncatalogue")
                    .font(DS.Typography.label)
                    .foregroundColor(DS.Colour.textPrimary)
                    .multilineTextAlignment(.leading)
                    .padding(DS.Spacing.sm)
            }
        }
    }

    private var posterPlaceholder: some View {
        ZStack {
            DS.Colour.surface
            Image(systemName: credit.mediaType == .movie ? "film" : "tv")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(DS.Colour.textTertiary)
        }
    }
}
