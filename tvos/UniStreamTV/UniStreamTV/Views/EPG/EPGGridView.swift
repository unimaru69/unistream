import SwiftUI
import Kingfisher

/// Guide TV — option B layout: one row per channel, programmes laid out in
/// a horizontal `LazyHStack` of focus-friendly cards. Each row scrolls
/// independently; the global vertical scroll moves between channels. The
/// focus engine handles `LazyHStack`/`LazyVStack` natively, so D-pad
/// navigation is robust without per-cell pixel-time positioning.
///
/// Loading is opportunistic: on day/category change we kick off the first
/// 30 channels, and each row's `.onAppear` requests its own EPG when it
/// scrolls into view. `EPGCache` deduplicates concurrent fetches.
struct EPGGridView: View {
    @Bindable var liveViewModel: LiveViewModel
    @Bindable var epgCache: EPGCache
    var onBackToCategories: (() -> Void)? = nil

    @Environment(AppState.self) private var appState

    // MARK: - State

    enum CategoryFilter: Hashable {
        case favorites
        case all
        case category(id: String)
    }

    @State private var dayOffset: Int = 0
    @State private var categoryFilter: CategoryFilter = .favorites
    @State private var searchText: String = ""
    @State private var isSearchActive: Bool = false
    @State private var transientToast: String?

    @FocusState private var focusedCell: CellID?

    enum CellID: Hashable {
        case program(channelId: String, programId: UUID)
        case search(programId: UUID)
    }

    // MARK: - Tunables

    /// Banner to the left of every row (logo + name + badges).
    private let bannerWidth: CGFloat = 280
    private let rowHeight: CGFloat = 96
    /// `width = clamp(durationMin × 4, 320, 800)`. Loose pixel-time mapping —
    /// preserves a sense of "this show is shorter than that one" without
    /// making 5-min interludes unreadable.
    private let pxPerMinute: CGFloat = 4
    private let cellMinWidth: CGFloat = 320
    private let cellMaxWidth: CGFloat = 800
    private let initialBatch: Int = 30

    // MARK: - Derived

    private var selectedDay: Date {
        Calendar.current.date(byAdding: .day, value: dayOffset, to: Date()) ?? Date()
    }
    private var dayKey: String { EPGCache.dayKey(for: selectedDay) }
    private var isToday: Bool { dayOffset == 0 }
    private var isLoading: Bool { epgCache.loadingDays.contains(dayKey) }
    private var loadProgress: (Int, Int)? { epgCache.loadProgress[dayKey] }

    private var visibleChannels: [Channel] {
        switch categoryFilter {
        case .favorites:
            let favIds = Set(appState.syncService.favorites.values
                .filter { $0.isLive }
                .compactMap { $0.resolvedStreamId })
            return liveViewModel.allChannels.filter { favIds.contains($0.streamId) }
        case .all:
            return liveViewModel.allChannels
        case .category(let id):
            return liveViewModel.allChannels.filter { $0.categoryId == id }
        }
    }

    /// Stable composite key. Re-evaluates the `.task` only on real filter
    /// changes — not on every `allChannels.count` jitter.
    private var filterKey: String {
        switch categoryFilter {
        case .favorites: return "fav"
        case .all: return "all"
        case .category(let id): return "cat:\(id)"
        }
    }
    private var cacheKey: String { "\(dayKey)|\(filterKey)" }

    private var timeshiftAllowed: Bool {
        FeatureAccess.canUse(.catchupReplay, account: appState.authService.cachedAccountInfo)
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            filterBar

            Group {
                if isSearchActive && !searchText.isEmpty {
                    searchResults
                } else {
                    grid
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.Colour.background)
        .task(id: cacheKey) {
            await primeFiltersIfNeeded()
            await preloadInitialBatch()
            // NB: we deliberately do *not* plant focus into the grid here.
            // The grid is presented as the right-hand preview pane of
            // LiveSplitView as soon as the sidebar focus *lands* on the
            // "Guide TV" entry (focus-driven preview, no tap). Imperatively
            // assigning `focusedCell` at that point yanked the focus engine
            // out of the sidebar and into a programme cell — so scrolling
            // the categories list "stuck" the moment it reached EPG. Focus
            // now stays in the sidebar; the user enters the grid by pressing
            // → into the detail .focusSection(), and the engine picks the
            // leftmost on-screen cell (the lane is already scrolled to "now").
        }
        .onChange(of: transientToast) { _, newValue in
            guard newValue != nil else { return }
            Task {
                try? await Task.sleep(for: .seconds(2.4))
                withAnimation(DS.Motion.standard) { transientToast = nil }
            }
        }
        .overlay(alignment: .bottom) { toastOverlay }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: DS.Spacing.md) {
            if let onBack = onBackToCategories {
                Button(action: onBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left").font(.caption)
                        Text("Catégories")
                    }
                }
                .buttonStyle(EPGHeaderButtonStyle())
            }

            Text("Guide TV")
                .font(DS.Typography.title1)
                .foregroundColor(DS.Colour.textPrimary)

            if isLoading, let prog = loadProgress {
                HStack(spacing: 6) {
                    ProgressView().tint(DS.Colour.textTertiary)
                    Text("\(prog.0)/\(prog.1)")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colour.textTertiary)
                }
                .transition(.opacity)
            }

            Spacer()

            if isSearchActive {
                TextField("Titre, chaîne…", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(DS.Typography.body)
                    .foregroundColor(DS.Colour.textPrimary)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.xs)
                    .frame(width: 360)
                    .background(Color.white.opacity(0.10), in: Capsule())
                    .submitLabel(.search)
            }

            Button {
                withAnimation(DS.Motion.standard) {
                    isSearchActive.toggle()
                    if !isSearchActive { searchText = "" }
                }
            } label: {
                Image(systemName: isSearchActive ? "xmark" : "magnifyingglass")
            }
            .buttonStyle(EPGHeaderButtonStyle())
        }
        .padding(.horizontal, DS.Padding.detailHorizontal)
        .padding(.top, DS.Spacing.lg)
        .padding(.bottom, DS.Spacing.xs)
    }

    // MARK: - Filter bar (two rows: days + categories)

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.xs) {
                    ForEach(-7...7, id: \.self) { offset in
                        Button { dayOffset = offset } label: {
                            Text(dayLabel(for: offset))
                        }
                        .buttonStyle(EPGChipButtonStyle(isSelected: dayOffset == offset))
                    }
                }
                .padding(.horizontal, DS.Padding.detailHorizontal)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.xs) {
                    Button { categoryFilter = .favorites } label: {
                        Label("Favoris", systemImage: "heart.fill")
                    }
                    .buttonStyle(EPGChipButtonStyle(isSelected: categoryFilter == .favorites))

                    Button { categoryFilter = .all } label: {
                        Label("Toutes", systemImage: "tv.fill")
                    }
                    .buttonStyle(EPGChipButtonStyle(isSelected: categoryFilter == .all))

                    ForEach(liveViewModel.categories, id: \.categoryId) { cat in
                        Button { categoryFilter = .category(id: cat.categoryId) } label: {
                            Text(cat.categoryName)
                        }
                        .buttonStyle(EPGChipButtonStyle(isSelected: categoryFilter == .category(id: cat.categoryId)))
                    }
                }
                .padding(.horizontal, DS.Padding.detailHorizontal)
            }
        }
        .padding(.bottom, DS.Spacing.sm)
    }

    private func dayLabel(for offset: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date()
        switch offset {
        case 0: return "Aujourd'hui"
        case 1: return "Demain"
        case -1: return "Hier"
        default: return Self.weekdayDateFmt.string(from: date).capitalized
        }
    }

    // MARK: - Grid

    @ViewBuilder
    private var grid: some View {
        if visibleChannels.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    ForEach(visibleChannels, id: \.streamId) { channel in
                        channelRow(channel)
                            .onAppear { triggerLoadIfNeeded(channel: channel) }
                    }
                }
                .padding(.horizontal, DS.Padding.detailHorizontal)
                .padding(.vertical, DS.Spacing.sm)
            }
        }
    }

    private func channelRow(_ channel: Channel) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            channelBanner(channel)
            programLane(for: channel)
        }
        .frame(height: rowHeight)
    }

    private func channelBanner(_ channel: Channel) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            KFImage(URL(string: channel.displayIcon))
                .resizable()
                .placeholder {
                    Image(systemName: "tv").foregroundColor(DS.Colour.textTertiary)
                }
                .aspectRatio(contentMode: .fit)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.tag))

            VStack(alignment: .leading, spacing: 4) {
                Text(channel.name.strippingProviderTag)
                    .font(DS.Typography.bodyEmphasised)
                    .foregroundColor(DS.Colour.textPrimary)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    if let n = channel.num {
                        Text("\(n)")
                            .font(.system(size: 11))
                            .foregroundColor(DS.Colour.textTertiary)
                    }
                    if channel.hasCatchup {
                        Text("REPLAY")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(DS.Colour.accentWarm.opacity(0.9), in: Capsule())
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DS.Spacing.sm)
        .frame(width: bannerWidth, height: rowHeight, alignment: .leading)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
    }

    @ViewBuilder
    private func programLane(for channel: Channel) -> some View {
        let progs = epgCache.byDay[dayKey]?[channel.streamId]
        if let progs, !progs.isEmpty {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: DS.Spacing.xs) {
                        ForEach(progs) { prog in
                            programCell(channel: channel, program: prog)
                                .id(prog.id)
                        }
                    }
                    .padding(.horizontal, DS.Spacing.xs)
                }
                .onAppear {
                    // Snap to "now" on first apparition for today; first
                    // future programme on past/future days.
                    let target: EpgProgram? = isToday
                        ? (progs.first(where: { isCurrent($0) }) ?? progs.first(where: { isUpcoming($0) }))
                        : progs.first
                    if let target {
                        proxy.scrollTo(target.id, anchor: .leading)
                    }
                }
            }
        } else if progs != nil {
            // Loaded but empty — provider returned nothing for this day.
            Text("Pas de programme")
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colour.textTertiary)
                .padding(.horizontal, DS.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            skeletonLane
        }
    }

    private var skeletonLane: some View {
        HStack(spacing: DS.Spacing.xs) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 360, height: rowHeight - 8)
            }
            Spacer(minLength: 0)
        }
        .redacted(reason: .placeholder)
    }

    private func programCell(channel: Channel, program: EpgProgram) -> some View {
        let id = CellID.program(channelId: channel.streamId, programId: program.id)
        let width = cellWidth(for: program)
        let hasReminder: Bool = {
            guard let s = program.start else { return false }
            return appState.reminderService.hasReminder(streamId: channel.streamId, startUtc: s)
        }()
        let runtime = runtimeState(of: program)
        let cellState: EPGCellButtonStyle.CellState
        let isCurrentNow: Bool
        switch runtime {
        case .current(let p):
            cellState = .current(progress: p)
            isCurrentNow = true
        case .past:
            cellState = .past
            isCurrentNow = false
        case .upcoming:
            cellState = .upcoming
            isCurrentNow = false
        }
        return Button {
            handleTap(channel: channel, program: program)
        } label: {
            ProgramCellLabel(program: program, isCurrent: isCurrentNow, hasReminder: hasReminder)
                .frame(width: width, height: rowHeight - 8)
        }
        .buttonStyle(EPGCellButtonStyle(state: cellState))
        .focused($focusedCell, equals: id)
    }

    private func cellWidth(for program: EpgProgram) -> CGFloat {
        let mins = max(15, program.durationMinutes)
        let raw = CGFloat(mins) * pxPerMinute
        return min(cellMaxWidth, max(cellMinWidth, raw))
    }

    // MARK: - Empty state

    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: DS.Spacing.sm) {
                Image(systemName: "tv.slash")
                    .font(.system(size: 36))
                    .foregroundColor(DS.Colour.textTertiary)
                Text(emptyMessage)
                    .font(DS.Typography.body)
                    .foregroundColor(DS.Colour.textSecondary)
            }
            Spacer()
        }
        .padding(.top, DS.Spacing.huge)
    }

    private var emptyMessage: String {
        switch categoryFilter {
        case .favorites: return "Aucune chaîne dans vos favoris"
        case .all: return "Aucune chaîne disponible"
        case .category: return "Aucune chaîne dans cette catégorie"
        }
    }

    // MARK: - Search

    private struct SearchMatch: Identifiable {
        let channel: Channel
        let program: EpgProgram
        var id: UUID { program.id }
    }

    @ViewBuilder
    private var searchResults: some View {
        let matches = computeSearchMatches()
        ScrollView {
            LazyVStack(spacing: DS.Spacing.xs) {
                if matches.isEmpty {
                    Text(searchText.isEmpty ? "Tapez pour rechercher" : "Aucun résultat")
                        .font(DS.Typography.body)
                        .foregroundColor(DS.Colour.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, DS.Spacing.huge)
                } else {
                    ForEach(matches) { match in
                        searchRow(match)
                    }
                }
            }
            .padding(.horizontal, DS.Padding.detailHorizontal)
            .padding(.vertical, DS.Spacing.sm)
        }
    }

    private func computeSearchMatches() -> [SearchMatch] {
        let q = searchText
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
        guard !q.isEmpty else { return [] }
        let dayMap = epgCache.byDay[dayKey] ?? [:]
        var out: [SearchMatch] = []
        for ch in visibleChannels {
            let chName = ch.name.strippingProviderTag
                .lowercased()
                .folding(options: .diacriticInsensitive, locale: .current)
            let chMatch = chName.contains(q)
            guard let progs = dayMap[ch.streamId] else { continue }
            for p in progs {
                let title = p.title
                    .lowercased()
                    .folding(options: .diacriticInsensitive, locale: .current)
                if chMatch || title.contains(q) {
                    out.append(SearchMatch(channel: ch, program: p))
                }
            }
        }
        return out.sorted { ($0.program.start ?? .distantPast) < ($1.program.start ?? .distantPast) }
    }

    private func searchRow(_ match: SearchMatch) -> some View {
        let id = CellID.search(programId: match.program.id)
        return Button {
            handleTap(channel: match.channel, program: match.program)
        } label: {
            HStack(spacing: DS.Spacing.md) {
                KFImage(URL(string: match.channel.displayIcon))
                    .resizable()
                    .placeholder {
                        Image(systemName: "tv").foregroundColor(DS.Colour.textTertiary)
                    }
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.tag))

                VStack(alignment: .leading, spacing: 3) {
                    Text(match.program.title)
                        .font(DS.Typography.bodyEmphasised)
                        .foregroundColor(DS.Colour.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        if let s = match.program.start {
                            Text(Self.timeFmt.string(from: s))
                                .font(DS.Typography.caption)
                                .foregroundColor(DS.Colour.textTertiary)
                        }
                        Text("·")
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colour.textTertiary)
                        Text(match.channel.name.strippingProviderTag)
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colour.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                stateTag(match.program)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(EPGSearchRowButtonStyle())
        .focused($focusedCell, equals: id)
    }

    @ViewBuilder
    private func stateTag(_ program: EpgProgram) -> some View {
        switch runtimeState(of: program) {
        case .current:
            Text("EN COURS")
                .font(.system(size: 10, weight: .heavy))
                .foregroundColor(.white)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(DS.Colour.accentWarm, in: Capsule())
        case .past:
            Text("PASSÉ")
                .font(.system(size: 10, weight: .heavy))
                .foregroundColor(DS.Colour.textTertiary)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Color.white.opacity(0.06), in: Capsule())
        case .upcoming:
            Text("À VENIR")
                .font(.system(size: 10, weight: .heavy))
                .foregroundColor(DS.Colour.textSecondary)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Color.white.opacity(0.06), in: Capsule())
        }
    }

    // MARK: - Tap routing

    /// Lifecycle state derived from the programme's `start`.
    ///
    /// We deliberately don't trust `EpgProgram.isPast` (which keys off
    /// `end`) because some Xtream providers serve corrupted
    /// `stop_timestamp` values (zero / 1970 epoch). That flipped `isPast`
    /// to true on perfectly future programmes — tapping a "demain matin"
    /// cell tried to launch a replay instead of offering a reminder.
    /// Anchoring on `start` makes the routing immune to bad `end`.
    private enum ProgramRuntimeState {
        case past
        case current(progress: Double)
        case upcoming
    }

    private func runtimeState(of program: EpgProgram) -> ProgramRuntimeState {
        let now = Date()
        let start = program.start ?? .distantFuture
        let end = program.end ?? .distantFuture
        if start > now { return .upcoming }
        if end > now { return .current(progress: program.progress) }
        return .past
    }

    private func isCurrent(_ p: EpgProgram) -> Bool {
        if case .current = runtimeState(of: p) { return true }
        return false
    }

    private func isUpcoming(_ p: EpgProgram) -> Bool {
        if case .upcoming = runtimeState(of: p) { return true }
        return false
    }

    private func handleTap(channel: Channel, program: EpgProgram) {
        switch runtimeState(of: program) {
        case .current:
            playLive(for: channel)
        case .past:
            playReplayOrFail(channel: channel, program: program)
        case .upcoming:
            let added = appState.reminderService.toggle(
                streamId: channel.streamId,
                channelName: channel.name.strippingProviderTag,
                program: program
            )
            withAnimation(DS.Motion.standard) {
                transientToast = added
                    ? "🔔 Rappel posé pour « \(program.title) »"
                    : "Rappel retiré"
            }
        }
    }

    private func playLive(for channel: Channel) {
        let chans = visibleChannels
        let idx = chans.firstIndex(where: { $0.streamId == channel.streamId }) ?? 0
        PlayerPresenter.playLiveWithZapping(
            channels: chans,
            startIndex: idx,
            api: appState.api,
            timeshiftAllowed: timeshiftAllowed
        )
    }

    private func playReplayOrFail(channel: Channel, program: EpgProgram) {
        guard channel.hasCatchup,
              let url = appState.api.timeshiftUrlFromLocal(
                  streamId: channel.streamId,
                  serverLocalStart: program.serverLocalStart,
                  durationMinutes: program.durationMinutes
              )
        else {
            withAnimation(DS.Motion.standard) {
                transientToast = "Replay non disponible chez votre fournisseur."
            }
            return
        }
        PlayerPresenter.playCatchUp(
            url: url,
            title: "\(channel.name.strippingProviderTag) — \(program.title)"
        )
    }

    // MARK: - Toast

    @ViewBuilder
    private var toastOverlay: some View {
        if let msg = transientToast {
            Text(msg)
                .font(DS.Typography.body)
                .foregroundColor(DS.Colour.textPrimary)
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.sm)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.bottom, DS.Spacing.xl)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Loading

    private func primeFiltersIfNeeded() async {
        if liveViewModel.allChannels.isEmpty {
            await liveViewModel.loadAllChannels()
        }
        if liveViewModel.categories.isEmpty {
            await liveViewModel.loadCategories()
        }
    }

    private func preloadInitialBatch() async {
        let initial = Array(visibleChannels.prefix(initialBatch))
        guard !initial.isEmpty else { return }
        await epgCache.loadDay(selectedDay, channels: initial, api: appState.api)
    }

    /// Called from each row's `.onAppear` — `EPGCache.loadDay` no-ops on
    /// already-cached / in-flight channels, so calling it per row is safe
    /// even if it's not the most efficient batching strategy.
    private func triggerLoadIfNeeded(channel: Channel) {
        guard epgCache.byDay[dayKey]?[channel.streamId] == nil else { return }
        let day = selectedDay
        Task {
            await epgCache.loadDay(day, channels: [channel], api: appState.api)
        }
    }

    // MARK: - Formatters

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
    private static let weekdayDateFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "EEE d MMM"
        return f
    }()
}

// MARK: - Cell label

private struct ProgramCellLabel: View {
    let program: EpgProgram
    let isCurrent: Bool
    let hasReminder: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if let s = program.start {
                    Text(Self.timeFmt.string(from: s))
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colour.textTertiary)
                }
                if program.durationMinutes > 0 {
                    Text("· \(program.durationMinutes) min")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colour.textTertiary)
                }
                if isCurrent {
                    Text("EN COURS")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(DS.Colour.accentWarm, in: Capsule())
                }
                if hasReminder {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 10))
                        .foregroundColor(DS.Colour.warning)
                }
                Spacer(minLength: 0)
            }
            Text(program.title)
                .font(DS.Typography.bodyEmphasised)
                .foregroundColor(DS.Colour.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
}

// MARK: - Button styles

private struct EPGHeaderButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.Typography.bodyEmphasised)
            .foregroundColor(isFocused ? .black : DS.Colour.textSecondary)
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.xs)
            .background(
                isFocused
                ? AnyShapeStyle(Color.white)
                : AnyShapeStyle(Color.white.opacity(0.10))
            )
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : (isFocused ? DS.Focus.chipScale : 1.0))
            .animation(DS.Focus.animation, value: isFocused)
    }
}

private struct EPGChipButtonStyle: ButtonStyle {
    let isSelected: Bool
    @Environment(\.isFocused) private var isFocused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.Typography.bodyEmphasised)
            .foregroundColor(textColor)
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.xs)
            .background(background)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : (isFocused ? DS.Focus.chipScale : 1.0))
            .animation(DS.Focus.animation, value: isFocused)
    }

    private var textColor: Color {
        if isFocused { return .black }
        return isSelected ? DS.Colour.textPrimary : DS.Colour.textSecondary
    }

    @ViewBuilder
    private var background: some View {
        if isFocused {
            Color.white
        } else if isSelected {
            DS.Colour.accent
        } else {
            Color.white.opacity(0.10)
        }
    }
}

private struct EPGCellButtonStyle: ButtonStyle {
    enum CellState {
        case past
        case current(progress: Double)
        case upcoming
    }
    let state: CellState
    @Environment(\.isFocused) private var isFocused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(background)
            .overlay(alignment: .bottomLeading) { progressBar }
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .strokeBorder(
                        isFocused ? DS.Colour.accent : Color.white.opacity(0.08),
                        lineWidth: isFocused ? 2 : 1
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : (isFocused ? 1.04 : 1.0))
            .animation(DS.Focus.animation, value: isFocused)
    }

    @ViewBuilder
    private var progressBar: some View {
        if case .current(let p) = state {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.white.opacity(0.10))
                        .frame(height: 3)
                    Rectangle()
                        .fill(DS.Colour.accentWarm)
                        .frame(width: max(0, geo.size.width * CGFloat(min(1, max(0, p)))), height: 3)
                }
            }
            .frame(height: 3)
        }
    }

    @ViewBuilder
    private var background: some View {
        switch state {
        case .current:
            DS.Colour.accent.opacity(isFocused ? 0.55 : 0.30)
        case .past:
            Color.white.opacity(isFocused ? 0.12 : 0.04)
        case .upcoming:
            DS.Colour.surface.opacity(isFocused ? 1.0 : 0.75)
        }
    }
}

private struct EPGSearchRowButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                isFocused ? DS.Colour.accent.opacity(0.30) : Color.white.opacity(0.04)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .strokeBorder(
                        isFocused ? DS.Colour.accent : Color.white.opacity(0.08),
                        lineWidth: isFocused ? 2 : 1
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.99 : (isFocused ? 1.02 : 1.0))
            .animation(DS.Focus.animation, value: isFocused)
    }
}
