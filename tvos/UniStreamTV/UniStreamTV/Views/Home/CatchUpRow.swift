import SwiftUI
import Kingfisher

/// Horizontal row of recent catch-up (replay) programs on the Home tab.
struct CatchUpRow: View {
    @Environment(AppState.self) private var appState
    @State private var items: [CatchUpItem] = []
    @State private var isLoading = false

    var body: some View {
        Group {
            if isLoading {
                VStack(alignment: .leading, spacing: 16) {
                    sectionHeader
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                }
            } else if !items.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    sectionHeader

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 24) {
                            ForEach(items) { item in
                                Button {
                                    playCatchUp(item)
                                } label: {
                                    catchUpCard(item)
                                }
                                .buttonStyle(.tvCard)
                            }
                        }
                        .padding(.horizontal, 50)
                    }
                }
            }
        }
        .task {
            await loadCatchUpPrograms()
        }
    }

    private var sectionHeader: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "gobackward")
                .foregroundColor(DS.Colour.accentWarm)
            Text("Replay disponible")
                .font(DS.Typography.title2)
                .foregroundColor(DS.Colour.textPrimary)
        }
        .padding(.horizontal, DS.Padding.screenHorizontal)
    }

    @ViewBuilder
    private func catchUpCard(_ item: CatchUpItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomLeading) {
                KFImage(URL(string: item.channelIcon))
                    .placeholder {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(hex: 0x161230))
                            .overlay {
                                Image(systemName: "gobackward")
                                    .font(.title2)
                                    .foregroundColor(.orange.opacity(0.4))
                            }
                    }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 260, height: 146)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                // Channel name badge
                Text(item.channelName)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4))
                    .padding(8)
            }
            .frame(width: 260, height: 146)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.programTitle)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Text(item.timeLabel)
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text("•")
                        .foregroundColor(.gray)
                    Text("\(item.durationMinutes) min")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            .frame(width: 260, alignment: .leading)
        }
    }

    // MARK: - Data Loading

    @MainActor
    private func loadCatchUpPrograms() async {
        guard items.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        let api = appState.api
        guard api.isAuthenticated else { return }

        // Get all channels, filter catch-up enabled
        let allChannels: [Channel]
        do {
            allChannels = try await api.getLiveStreams()
        } catch { return }

        let catchUpChannels = allChannels
            .filter { $0.hasCatchup }
            .prefix(15) // Limit to 15 channels for performance

        // Load short EPG for each catch-up channel
        var collected: [CatchUpItem] = []
        let now = Date()
        let cutoff = now.addingTimeInterval(-24 * 3600)

        await withTaskGroup(of: (Channel, [EpgProgram]).self) { group in
            for channel in catchUpChannels {
                group.addTask {
                    let programs = (try? await api.getShortEpg(streamId: channel.streamId, limit: 8)) ?? []
                    return (channel, programs)
                }
            }
            for await (channel, programs) in group {
                let pastPrograms = programs.filter { prog in
                    guard let end = prog.end else { return false }
                    return prog.isPast && end > cutoff && prog.durationMinutes > 0 && !prog.title.isEmpty
                }
                for prog in pastPrograms {
                    collected.append(CatchUpItem(
                        channel: channel,
                        program: prog
                    ))
                }
            }
        }

        items = collected
            .sorted { ($0.program.end ?? .distantPast) > ($1.program.end ?? .distantPast) }
            .prefix(20)
            .map { $0 }
    }

    private func playCatchUp(_ item: CatchUpItem) {
        let title = "\(item.channelName) — \(item.programTitle) (Replay)"
        let program = item.program

        if !program.serverLocalStart.isEmpty,
           let url = appState.api.timeshiftUrlFromLocal(
               streamId: item.channelStreamId,
               serverLocalStart: program.serverLocalStart,
               durationMinutes: program.durationMinutes
           ) {
            PlayerPresenter.playCatchUp(url: url, title: title)
            return
        }

        if let startUtc = program.start,
           let url = appState.api.timeshiftUrl(
               streamId: item.channelStreamId,
               startUtc: startUtc,
               durationMinutes: program.durationMinutes
           ) {
            PlayerPresenter.playCatchUp(url: url, title: title)
        }
    }
}

// MARK: - Model

struct CatchUpItem: Identifiable {
    let id = UUID()
    let channelStreamId: String
    let channelName: String
    let channelIcon: String
    let programTitle: String
    let durationMinutes: Int
    let timeLabel: String
    let program: EpgProgram

    init(channel: Channel, program: EpgProgram) {
        self.channelStreamId = channel.streamId
        self.channelName = channel.name
        self.channelIcon = channel.displayIcon
        self.programTitle = program.title
        self.durationMinutes = program.durationMinutes
        self.program = program

        // Format time label
        if let start = program.start {
            let fmt = DateFormatter()
            fmt.dateFormat = "HH:mm"
            self.timeLabel = fmt.string(from: start)
        } else {
            self.timeLabel = ""
        }
    }
}
