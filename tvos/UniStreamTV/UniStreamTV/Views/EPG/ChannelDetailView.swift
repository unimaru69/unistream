import SwiftUI
import Kingfisher

/// Full-screen channel detail — play live, browse programs, replay catch-up.
struct ChannelDetailView: View {
    @Environment(AppState.self) private var appState

    let channel: Channel
    let allChannels: [Channel]

    @State private var programs: [EpgProgram] = []
    @State private var isLoading = true

    private var currentProgram: EpgProgram? {
        programs.first(where: { $0.isCurrent })
    }

    private var upcomingPrograms: [EpgProgram] {
        let now = Date()
        return programs
            .filter { !$0.isPast && !$0.isCurrent && ($0.start ?? .distantFuture) > now }
            .sorted { ($0.start ?? .distantFuture) < ($1.start ?? .distantFuture) }
    }

    private var catchUpPrograms: [EpgProgram] {
        guard channel.hasCatchup else { return [] }
        let cutoff = Date().addingTimeInterval(-24 * 3600)
        return programs
            .filter { $0.isPast && ($0.end ?? .distantPast) > cutoff && $0.durationMinutes > 0 && !$0.title.isEmpty }
            .sorted { ($0.start ?? .distantPast) > ($1.start ?? .distantPast) }
    }

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // Channel header
                channelHeader

                // Current program
                if let current = currentProgram {
                    currentProgramSection(current)
                }

                // Play live button
                Button {
                    playLive()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "play.fill")
                            .font(.title3)
                        Text("Regarder en direct")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
                .buttonStyle(.tvRow)

                // Catch-up replay section
                if !catchUpPrograms.isEmpty {
                    catchUpSection
                }

                // Upcoming programs
                if !upcomingPrograms.isEmpty {
                    upcomingSection
                }

                // Loading
                if isLoading {
                    ProgressView("Chargement des programmes…")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 20)
                }

                // Empty state
                if !isLoading && programs.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 32))
                            .foregroundColor(.gray.opacity(0.4))
                        Text("Aucun programme disponible")
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
                }
            }
            .padding(50)
        }
        // Solid background so a fullScreenCover presentation actually
        // covers what's behind. Without it the parent (e.g. EPG grid +
        // LiveSplitView sidebar) bleeds through and the page reads as
        // a translucent overlay rather than a fresh screen.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.Colour.background.ignoresSafeArea())
        .navigationTitle(channel.name)
        .task {
            await loadPrograms()
        }
    }

    // MARK: - Channel Header

    private var channelHeader: some View {
        HStack(spacing: 20) {
            KFImage(URL(string: channel.displayIcon))
                .resizable()
                .placeholder {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: 0x161230))
                        .frame(width: 80, height: 80)
                }
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(channel.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                HStack(spacing: 12) {
                    if let num = channel.num {
                        Text("N° \(num)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    if channel.hasCatchup {
                        HStack(spacing: 4) {
                            Image(systemName: "gobackward")
                            Text("Replay \(channel.archiveDays)j")
                        }
                        .font(.caption)
                        .foregroundColor(.orange)
                    }
                }
            }

            Spacer()

            // Favorite toggle
            Button {
                appState.syncService.toggleFavorite(.from(channel: channel))
            } label: {
                Image(systemName: appState.syncService.isFavorite(channel.streamId) ? "heart.fill" : "heart")
                    .font(.title3)
                    .foregroundColor(appState.syncService.isFavorite(channel.streamId) ? .yellow : .gray)
            }
        }
    }

    // MARK: - Current Program

    @ViewBuilder
    private func currentProgramSection(_ program: EpgProgram) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text("EN DIRECT")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.red, in: Capsule())

                Text(program.title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }

            ProgressView(value: program.progress)
                .tint(Color(hex: 0x1B6B8A))

            HStack {
                if let start = program.start {
                    Text(Self.timeFmt.string(from: start))
                }
                Text("—")
                if let end = program.end {
                    Text(Self.timeFmt.string(from: end))
                }
                Text("•")
                Text("\(program.durationMinutes) min")
            }
            .font(.caption)
            .foregroundColor(.gray)
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
    }

    // MARK: - Catch-Up Section

    private var catchUpSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "gobackward")
                    .foregroundColor(.orange)
                Text("Replay disponible")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            ForEach(catchUpPrograms.prefix(15)) { program in
                Button {
                    playCatchUp(program)
                } label: {
                    HStack(spacing: 16) {
                        // Time
                        VStack(spacing: 2) {
                            if let start = program.start {
                                Text(Self.timeFmt.string(from: start))
                                    .font(.headline)
                                    .foregroundColor(.orange)
                            }
                            if let end = program.end {
                                Text(Self.timeFmt.string(from: end))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .frame(width: 60, alignment: .trailing)

                        // Title + duration
                        VStack(alignment: .leading, spacing: 4) {
                            Text(program.title)
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .lineLimit(2)
                            Text("\(program.durationMinutes) min")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }

                        Spacer()

                        // Play indicator
                        Image(systemName: "play.circle.fill")
                            .font(.title2)
                            .foregroundColor(.orange)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                }
                .buttonStyle(.tvRow)
            }
        }
    }

    // MARK: - Upcoming Section

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("À venir")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)

            ForEach(upcomingPrograms.prefix(10)) { program in
                HStack(spacing: 16) {
                    VStack(spacing: 2) {
                        if let start = program.start {
                            Text(Self.timeFmt.string(from: start))
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        if let end = program.end {
                            Text(Self.timeFmt.string(from: end))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(width: 60, alignment: .trailing)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(program.title)
                            .font(.body)
                            .foregroundColor(.white)
                            .lineLimit(2)
                        Text("\(program.durationMinutes) min")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    // Reminder toggle
                    if program.start != nil {
                        Button {
                            appState.reminderService.toggle(
                                streamId: channel.streamId,
                                channelName: channel.name,
                                program: program
                            )
                        } label: {
                            let hasReminder = appState.reminderService.hasReminder(
                                streamId: channel.streamId,
                                startUtc: program.start!
                            )
                            Image(systemName: hasReminder ? "bell.fill" : "bell")
                                .font(.title3)
                                .foregroundColor(hasReminder ? .yellow : .gray)
                        }
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Actions

    private func playLive() {
        if let index = allChannels.firstIndex(where: { $0.streamId == channel.streamId }) {
            PlayerPresenter.playLiveWithZapping(
                channels: allChannels,
                startIndex: index,
                api: appState.api,
                timeshiftAllowed: FeatureAccess.canUse(.catchupReplay, account: appState.authService.cachedAccountInfo)
            )
        } else {
            guard let url = appState.api.liveStreamUrl(streamId: channel.streamId) else { return }
            PlayerPresenter.playLive(url: url, title: channel.name, contentKey: "live_\(channel.streamId)")
        }
    }

    private func playCatchUp(_ program: EpgProgram) {
        let title = "\(channel.name) — \(program.title) (Replay)"

        if !program.serverLocalStart.isEmpty,
           let url = appState.api.timeshiftUrlFromLocal(
               streamId: channel.streamId,
               serverLocalStart: program.serverLocalStart,
               durationMinutes: program.durationMinutes
           ) {
            PlayerPresenter.playCatchUp(url: url, title: title)
            return
        }

        if let startUtc = program.start,
           let url = appState.api.timeshiftUrl(
               streamId: channel.streamId,
               startUtc: startUtc,
               durationMinutes: program.durationMinutes
           ) {
            PlayerPresenter.playCatchUp(url: url, title: title)
        }
    }

    // MARK: - Data Loading

    private func loadPrograms() async {
        isLoading = true
        do {
            programs = try await appState.api.getFullDayEpg(streamId: channel.streamId)
        } catch {
            // Fallback to short EPG
            programs = (try? await appState.api.getShortEpg(streamId: channel.streamId, limit: 10)) ?? []
        }
        isLoading = false
    }
}
