import SwiftUI
import Kingfisher

/// Bottom-of-grid preview panel for Live: shows the focused channel's
/// current programme (title, times, progress bar, TMDB-enriched image
/// when one resolves) plus the next programme below.
///
/// Same architecture as `FocusedItemPreview` (Films / Séries) — sits
/// pinned at the bottom of the grid, fades + slides in/out as the
/// focus engine moves between channels.
struct LiveFocusedPreview: View {
    let channel: Channel
    let currentProgram: EpgProgram?
    let nextProgram: EpgProgram?

    @State private var tmdbVM = TMDBViewModel()

    private var artURL: URL? {
        // Prefer TMDB backdrop when the program resolves against
        // TMDB. Falls back to the channel logo so the panel is never
        // blank — broadcast-only / sports content rarely matches TMDB.
        if let url = tmdbVM.result?.backdropURL(size: "w780") {
            return url
        }
        return URL(string: channel.displayIcon)
    }

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.lg) {
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                channelLine
                if let prog = currentProgram {
                    currentProgramBlock(prog)
                } else {
                    Text("Aucune information de programme")
                        .font(DS.Typography.body)
                        .foregroundColor(DS.Colour.textTertiary)
                }
                if let next = nextProgram {
                    nextProgramLine(next)
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            artwork
        }
        .padding(.horizontal, DS.Padding.screenHorizontal)
        // Asymmetric vertical padding: a tall top lead-in (64 pt)
        // gives the dark fade plenty of vertical room to bloom up
        // from behind the text — the panel reads as a generous
        // "rise from the screen bottom" instead of a tight strip.
        // The bottom padding stays modest so the channel info still
        // sits comfortably near the bottom edge.
        .padding(.top, DS.Spacing.xxxl)
        .padding(.bottom, DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .background(
            LinearGradient(
                colors: [
                    DS.Colour.background.opacity(0.0),
                    DS.Colour.background.opacity(0.75),
                    DS.Colour.background.opacity(0.95),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .task(id: currentProgram?.title) {
            // Only attempt a TMDB lookup when there's a current program
            // — broadcasts without EPG would otherwise spam empty
            // searches against the API.
            guard let title = currentProgram?.title, !title.isEmpty else { return }
            // We don't know in advance whether the programme is a
            // movie or a TV series — try TV first (most live content
            // is series), fall back to movie if nothing matches.
            await tmdbVM.load(rawTitle: title, kind: .tv)
        }
    }

    private var artwork: some View {
        KFImage(artURL)
            .resizable()
            .placeholder {
                RoundedRectangle(cornerRadius: DS.Radius.card)
                    .fill(DS.Colour.surface)
                    .overlay {
                        Image(systemName: "tv")
                            .foregroundColor(DS.Colour.textTertiary)
                    }
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 160, height: 90)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
    }

    private var channelLine: some View {
        HStack(spacing: DS.Spacing.xs) {
            if let num = channel.num {
                Text("\(num)")
                    .font(DS.Typography.label)
                    .foregroundColor(DS.Colour.textTertiary)
            }
            Text(channel.name.strippingProviderTag)
                .font(DS.Typography.title3)
                .foregroundColor(DS.Colour.textSecondary)
                .lineLimit(1)
            if channel.hasCatchup {
                Text("REPLAY")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(DS.Colour.accentWarm, in: Capsule())
            }
        }
    }

    private func currentProgramBlock(_ prog: EpgProgram) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(prog.title)
                .font(DS.Typography.title2)
                .foregroundColor(DS.Colour.textPrimary)
                .lineLimit(1)

            HStack(spacing: DS.Spacing.sm) {
                if let s = prog.start, let e = prog.end {
                    Text("\(timeFmt.string(from: s)) – \(timeFmt.string(from: e))")
                }
                if prog.isCurrent {
                    HStack(spacing: 4) {
                        Circle().fill(DS.Colour.accentWarm).frame(width: 6, height: 6)
                        Text("EN DIRECT").fontWeight(.bold)
                    }
                    .foregroundColor(DS.Colour.accentWarm)
                }
            }
            .font(DS.Typography.caption)
            .foregroundColor(DS.Colour.textTertiary)

            if prog.isCurrent {
                ProgressView(value: prog.progress)
                    .tint(DS.Colour.accentWarm)
                    .frame(maxWidth: 360)
            }
        }
    }

    private func nextProgramLine(_ next: EpgProgram) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.right")
                .font(.caption2)
                .foregroundColor(DS.Colour.textTertiary)
            Text("Ensuite : \(next.title)")
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colour.textTertiary)
                .lineLimit(1)
            if let s = next.start {
                Text("· \(timeFmt.string(from: s))")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colour.textTertiary)
            }
        }
    }

    private let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()
}
