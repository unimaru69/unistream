import SwiftUI
import Kingfisher

/// True 2-axis EPG grid — channels on Y, time on X. The header lets
/// the user switch category and day without leaving the view, and
/// the underlying data is cached on `AppState.epgCache` so re-
/// entering the screen doesn't re-fetch what's already there.
struct EPGGridView: View {
    @Bindable var liveViewModel: LiveViewModel
    /// Direct binding to the cache — passing the reference explicitly
    /// (rather than reaching for `appState.epgCache` from inside the
    /// body) makes the SwiftUI Observation framework track byDay
    /// changes on this exact instance. The previous version's
    /// nested `appState.epgCache.programs(...)` access didn't
    /// trigger re-renders reliably when the cache mutated, which is
    /// why the grid stayed empty even though the loader logged
    /// "cached for 51 channels".
    @Bindable var epgCache: EPGCache
    /// Optional dismiss callback — wired from `LiveSplitView` so the
    /// "← Catégories" button has somewhere to go. Optional so the
    /// view stays usable in a preview / standalone test context.
    var onBackToCategories: (() -> Void)? = nil

    @Environment(AppState.self) private var appState

    @FocusState private var focusedCell: EPGCellId?
    @State private var selectedProgram: ProgramSelection?

    /// Selected category id. `nil` = "Toutes les chaînes". Special
    /// value `__favorites__` filters by live favourites.
    @State private var selectedCategoryId: String? = "__favorites__"
    /// Day offset relative to today: -3 → 3 days ago, 0 → today,
    /// 2 → in 2 days. The strip allows -3 … +2.
    @State private var dayOffset: Int = 0

    private let pixelsPerMinute: CGFloat = 5
    private let rowHeight: CGFloat = 80
    private let channelColumnWidth: CGFloat = 200
    private let headerHeight: CGFloat = 44
    private let maxChannelsPerView: Int = 50

    // MARK: - Derived state

    private var selectedDay: Date {
        Calendar.current.date(byAdding: .day, value: dayOffset, to: Date()) ?? Date()
    }
    private var isToday: Bool { dayOffset == 0 }

    /// Channels visible in the grid for the current category +
    /// favourites slicing. Capped at `maxChannelsPerView` so the
    /// load is bounded.
    private var visibleChannels: [Channel] {
        let pool: [Channel]
        switch selectedCategoryId {
        case "__favorites__":
            let favIds = Set(appState.syncService.favorites.values
                .filter { $0.isLive }
                .compactMap { $0.resolvedStreamId })
            pool = liveViewModel.allChannels.filter { favIds.contains($0.streamId) }
        case let cat? where !cat.isEmpty:
            pool = liveViewModel.allChannels.filter { $0.categoryId == cat }
        default:
            pool = liveViewModel.allChannels
        }
        return Array(pool.prefix(maxChannelsPerView))
    }

    /// Anchor for "today": now floored to the previous hour, minus
    /// 1 h. Going further back used to make the grid look empty on
    /// first paint — `getShortEpg` only returns programmes from
    /// roughly "now" forward, so a wide backward window meant the
    /// initial scroll position (gridStart, leftmost) showed only
    /// empty cells before the programmes appeared on the right
    /// edge. Deeper catch-up is reachable via the day picker.
    private var gridStart: Date {
        let cal = Calendar.current
        if isToday {
            let now = Date()
            let flooredHour = cal.dateInterval(of: .hour, for: now)?.start ?? now
            return cal.date(byAdding: .hour, value: -1, to: flooredHour) ?? flooredHour
        } else {
            return cal.startOfDay(for: selectedDay)
        }
    }
    private var gridEnd: Date {
        Calendar.current.date(byAdding: .hour, value: isToday ? 12 : 24, to: gridStart) ?? gridStart
    }
    private var totalMinutes: CGFloat {
        CGFloat(gridEnd.timeIntervalSince(gridStart) / 60)
    }
    private var totalGridWidth: CGFloat {
        totalMinutes * pixelsPerMinute
    }

    private var dayKey: String { EPGCache.dayKey(for: selectedDay) }
    private var isLoading: Bool { epgCache.loadingDays.contains(dayKey) }
    private var loadProgress: (Int, Int)? { epgCache.loadProgress[dayKey] }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            filterBar
            ScrollView([.horizontal, .vertical], showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    timeMarkers
                        .frame(width: channelColumnWidth + totalGridWidth, height: headerHeight)

                    if visibleChannels.isEmpty {
                        emptyState
                    } else {
                        ForEach(visibleChannels) { channel in
                            channelRow(channel)
                                .frame(width: channelColumnWidth + totalGridWidth, height: rowHeight)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.Colour.background)
        .task(id: cacheKey) { await loadIfNeeded() }
        .fullScreenCover(item: $selectedProgram) { sel in
            ChannelDetailView(channel: sel.channel, allChannels: visibleChannels)
        }
    }

    /// Combined key so the .task fires when *either* day or category
    /// changes — and only then. Stable on view re-creation, which
    /// is what gives us the cache hit.
    private var cacheKey: String {
        "\(dayKey)|\(selectedCategoryId ?? "__all__")|\(visibleChannels.count)"
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: DS.Spacing.md) {
            if let onBack = onBackToCategories {
                Button(action: onBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.caption)
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
            }
            Spacer()
            Text(rangeFmt.string(from: gridStart) + " — " + rangeFmt.string(from: gridEnd))
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colour.textTertiary)
        }
        .padding(.horizontal, DS.Padding.screenHorizontal)
        .padding(.top, DS.Spacing.lg)
        .padding(.bottom, DS.Spacing.sm)
    }

    // MARK: - Filter bar (day + category in a single row)

    /// Single horizontal row combining day chips on the left and
    /// category chips on the right, separated by a thin divider.
    /// Stacked rows (the previous design) trapped the tvOS focus
    /// engine: pressing ↑ from a category chip didn't escape back to
    /// the day row. With one row, ↑↓ only ever hops between the
    /// filter bar and the grid below — much simpler for the engine.
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                // Day chips
                ForEach(-3...2, id: \.self) { offset in
                    Button {
                        dayOffset = offset
                    } label: {
                        Text(dayLabelInline(for: offset))
                    }
                    .buttonStyle(EPGChipButtonStyle(isSelected: dayOffset == offset))
                }

                // Visual separator between day filters and category
                // filters — keeps the eye oriented while scrolling.
                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 1, height: 24)
                    .padding(.horizontal, DS.Spacing.xs)

                // Category chips
                Button {
                    selectedCategoryId = "__favorites__"
                } label: {
                    Label("Favoris", systemImage: "heart.fill")
                }
                .buttonStyle(EPGChipButtonStyle(isSelected: selectedCategoryId == "__favorites__"))

                Button {
                    selectedCategoryId = nil
                } label: {
                    Label("Toutes", systemImage: "tv.fill")
                }
                .buttonStyle(EPGChipButtonStyle(isSelected: selectedCategoryId == nil))

                ForEach(liveViewModel.categories, id: \.categoryId) { cat in
                    Button {
                        selectedCategoryId = cat.categoryId
                    } label: {
                        Text(cat.categoryName)
                    }
                    .buttonStyle(EPGChipButtonStyle(isSelected: selectedCategoryId == cat.categoryId))
                }
            }
            .padding(.horizontal, DS.Padding.screenHorizontal)
        }
        .padding(.bottom, DS.Spacing.sm)
    }

    /// Single-line day label combining relative term + date —
    /// "Aujourd'hui · 8 mai" / "Hier · 7 mai" / "ven · 9 mai".
    private func dayLabelInline(for offset: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date()
        let dateStr = shortDateFmt.string(from: date)
        switch offset {
        case 0: return "Aujourd'hui · \(dateStr)"
        case 1: return "Demain · \(dateStr)"
        case -1: return "Hier · \(dateStr)"
        default:
            let weekday = weekdayFmt.string(from: date).capitalized
            return "\(weekday) · \(dateStr)"
        }
    }

    // MARK: - Time markers row

    private var timeMarkers: some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                Rectangle().fill(Color.clear).frame(width: channelColumnWidth)
                Rectangle().fill(Color.white.opacity(0.04)).frame(width: totalGridWidth)
            }
            ForEach(timeTicks, id: \.self) { date in
                Text(timeFmt.string(from: date))
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colour.textTertiary)
                    .frame(width: 60, alignment: .leading)
                    .offset(
                        x: channelColumnWidth + position(for: date),
                        y: headerHeight / 2 - 8
                    )
            }
            // Now indicator only when we're showing today.
            if isToday {
                let nowX = position(for: Date())
                if nowX >= 0 && nowX <= totalGridWidth {
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.caption2)
                        .foregroundColor(DS.Colour.accentWarm)
                        .offset(x: channelColumnWidth + nowX - 6, y: headerHeight - 16)
                }
            }
        }
    }

    private var timeTicks: [Date] {
        var result: [Date] = []
        var t = gridStart
        let cal = Calendar.current
        while t < gridEnd {
            result.append(t)
            t = cal.date(byAdding: .minute, value: 30, to: t) ?? t
        }
        return result
    }

    // MARK: - Channel row

    @ViewBuilder
    private func channelRow(_ channel: Channel) -> some View {
        ZStack(alignment: .leading) {
            VStack(spacing: 0) {
                Spacer()
                Rectangle().fill(Color.white.opacity(0.04)).frame(height: 1)
            }
            HStack(spacing: 0) {
                channelCell(channel).frame(width: channelColumnWidth, height: rowHeight)
                programGrid(channel).frame(width: totalGridWidth, height: rowHeight)
            }
        }
    }

    private func channelCell(_ channel: Channel) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            KFImage(URL(string: channel.displayIcon))
                .resizable()
                .placeholder {
                    Image(systemName: "tv").foregroundColor(DS.Colour.textTertiary)
                }
                .aspectRatio(contentMode: .fit)
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 2) {
                Text(channel.name.strippingProviderTag)
                    .font(DS.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(DS.Colour.textPrimary)
                    .lineLimit(2)
                if let num = channel.num {
                    Text("\(num)")
                        .font(.system(size: 10))
                        .foregroundColor(DS.Colour.textTertiary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DS.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.02))
    }

    @ViewBuilder
    private func programGrid(_ channel: Channel) -> some View {
        ZStack(alignment: .leading) {
            ForEach(timeTicks.dropFirst(), id: \.self) { date in
                Rectangle()
                    .fill(Color.white.opacity(0.03))
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
                    .offset(x: position(for: date))
            }
            if isToday {
                let nowX = position(for: Date())
                if nowX >= 0 && nowX <= totalGridWidth {
                    Rectangle()
                        .fill(DS.Colour.accentWarm)
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                        .offset(x: nowX)
                }
            }

            // Force the ZStack to observe `byDay` directly. Reaching
            // through `epgCache.programs(...)` calls a method whose
            // body access doesn't always register as a dependency
            // for the parent view's render context — pulling the
            // dictionary into a local lookup makes the read happen
            // *here*, in this view's tracked region.
            let dayMap = epgCache.byDay[EPGCache.dayKey(for: selectedDay)] ?? [:]
            let progs = dayMap[channel.streamId] ?? []

            // DEBUG counter — visible badge in each row showing the
            // programme count this row is seeing. If "0P" but logs
            // say cached, the binding is broken; if "5P" but no
            // cells visible, layoutCell is dropping them.
            Text("\(progs.count)P")
                .font(.system(size: 11, weight: .heavy))
                .foregroundColor(.yellow)
                .padding(.horizontal, 4)
                .background(Color.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 4))
                .offset(x: 4, y: 4)

            ForEach(progs) { prog in
                if let cell = layoutCell(for: prog) {
                    programCell(prog, channel: channel, layout: cell)
                        .frame(width: cell.width, height: rowHeight - 4)
                        .offset(x: cell.x, y: 2)
                }
            }
        }
        .frame(width: totalGridWidth, height: rowHeight)
    }

    private struct CellLayout {
        let x: CGFloat
        let width: CGFloat
    }
    private func layoutCell(for prog: EpgProgram) -> CellLayout? {
        guard let start = prog.start, let end = prog.end else { return nil }
        if end <= gridStart || start >= gridEnd { return nil }
        let clippedStart = max(start, gridStart)
        let clippedEnd = min(end, gridEnd)
        let x = position(for: clippedStart)
        let width = max(40, position(for: clippedEnd) - x)
        return CellLayout(x: x, width: width)
    }

    @ViewBuilder
    private func programCell(_ prog: EpgProgram, channel: Channel, layout: CellLayout) -> some View {
        let id = EPGCellId(channelId: channel.streamId, programId: prog.id)
        Button {
            selectedProgram = ProgramSelection(channel: channel, program: prog)
        } label: {
            ProgramCellLabel(program: prog)
        }
        .buttonStyle(EPGCellButtonStyle(state: state(for: prog)))
        .focused($focusedCell, equals: id)
    }

    private func state(for prog: EpgProgram) -> EPGCellButtonStyle.State {
        if prog.isCurrent { return .current }
        if prog.isPast { return .past }
        return .upcoming
    }

    // MARK: - Empty state

    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: DS.Spacing.sm) {
                Image(systemName: "tv.slash")
                    .font(.system(size: 36))
                    .foregroundColor(DS.Colour.textTertiary)
                Text(emptyStateMessage)
                    .font(DS.Typography.body)
                    .foregroundColor(DS.Colour.textSecondary)
            }
            Spacer()
        }
        .padding(.top, DS.Spacing.huge)
    }

    private var emptyStateMessage: String {
        switch selectedCategoryId {
        case "__favorites__": return "Aucune chaîne dans vos favoris"
        case nil: return "Aucune chaîne disponible"
        default: return "Aucune chaîne dans cette catégorie"
        }
    }

    // MARK: - Loaders

    private func loadIfNeeded() async {
        if liveViewModel.allChannels.isEmpty {
            await liveViewModel.loadAllChannels()
        }
        let channels = visibleChannels
        guard !channels.isEmpty else { return }
        await epgCache.loadDay(selectedDay, channels: channels, api: appState.api)
    }

    // MARK: - Math helpers

    private func position(for date: Date) -> CGFloat {
        let mins = CGFloat(date.timeIntervalSince(gridStart) / 60)
        return mins * pixelsPerMinute
    }

    // MARK: - Formatters

    private let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
    private let rangeFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE HH:mm"
        return f
    }()
    private let weekdayFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()
    private let shortDateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f
    }()
}

// MARK: - Program cell

private struct ProgramCellLabel: View {
    let program: EpgProgram

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(program.title)
                .font(DS.Typography.caption)
                .fontWeight(.semibold)
                .foregroundColor(DS.Colour.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            if let s = program.start {
                Text(timeFmt.string(from: s))
                    .font(.system(size: 10))
                    .foregroundColor(DS.Colour.textTertiary)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private let timeFmt: DateFormatter = {
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
    enum State { case past, current, upcoming }
    let state: State
    @Environment(\.isFocused) private var isFocused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(
                        isFocused ? Color.white : Color.white.opacity(0.10),
                        lineWidth: isFocused ? 2 : 1
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.99 : 1.0)
            .animation(DS.Focus.animation, value: isFocused)
    }

    @ViewBuilder
    private var background: some View {
        switch state {
        case .current:
            DS.Colour.accent.opacity(isFocused ? 0.55 : 0.30)
        case .past:
            DS.Colour.surface.opacity(isFocused ? 0.85 : 0.55)
        case .upcoming:
            DS.Colour.surface.opacity(isFocused ? 0.95 : 0.70)
        }
    }
}

// MARK: - Identifiers

struct EPGCellId: Hashable {
    let channelId: String
    let programId: UUID
}

private struct ProgramSelection: Identifiable {
    let channel: Channel
    let program: EpgProgram
    var id: UUID { program.id }
}
