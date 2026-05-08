import SwiftUI
import Kingfisher

/// True 2-axis EPG grid — channels on the Y axis, time on the X axis.
/// Standard "guide programmes" layout used by Free, Bbox, Apple TV
/// Channels: scroll horizontally to navigate the timeline, scroll
/// vertically to switch channels, focus a cell to see programme info.
///
/// The earlier `EPGView` was a 2-step picker (category → channel
/// list with the inline current program); this view is the temporal
/// grid users explicitly asked for in Session 4b.
struct EPGGridView: View {
    let channels: [Channel]
    let categoryNames: [String: String]
    /// Optional callback so the parent can dismiss the EPG view —
    /// `LiveSplitView` wires this to switch back to its default
    /// category selection so the user always has a way out without
    /// hunting for the Menu button.
    var onBackToCategories: (() -> Void)? = nil

    @Environment(AppState.self) private var appState

    @State private var epgViewModel: EPGViewModel?
    @FocusState private var focusedCell: EPGCellId?
    @State private var selectedProgram: ProgramSelection?

    /// Geometry tokens. Tweakable but tuned for 1080p tvOS — at 5pt
    /// per minute, an hour is 300pt wide → ~4-5h visible inside the
    /// 1500pt rightmost area without scrolling.
    private let pixelsPerMinute: CGFloat = 5
    private let rowHeight: CGFloat = 80
    private let channelColumnWidth: CGFloat = 200
    private let headerHeight: CGFloat = 44

    /// Anchor: now floored to the previous hour, minus 4 hours, so
    /// the user can scroll the timeline backwards into the catch-up
    /// window (most providers offer last-24h replay; 4h covers the
    /// "what was on this afternoon?" use case).
    private var gridStart: Date {
        let now = Date()
        let cal = Calendar.current
        let flooredHour = cal.dateInterval(of: .hour, for: now)?.start ?? now
        return cal.date(byAdding: .hour, value: -4, to: flooredHour) ?? flooredHour
    }
    /// 12-hour window — covers an entire evening + buffer either side.
    private var gridEnd: Date {
        Calendar.current.date(byAdding: .hour, value: 12, to: gridStart) ?? gridStart
    }
    private var totalMinutes: CGFloat {
        CGFloat(gridEnd.timeIntervalSince(gridStart) / 60)
    }
    private var totalGridWidth: CGFloat {
        totalMinutes * pixelsPerMinute
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ScrollView([.horizontal, .vertical], showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    timeMarkers
                        .frame(width: channelColumnWidth + totalGridWidth, height: headerHeight)

                    ForEach(channels) { channel in
                        channelRow(channel)
                            .frame(width: channelColumnWidth + totalGridWidth, height: rowHeight)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.Colour.background)
        .task(id: channels.map(\.streamId).joined()) {
            let vm = EPGViewModel(api: appState.api)
            epgViewModel = vm
            await vm.loadEPG(for: channels)
        }
        .fullScreenCover(item: $selectedProgram) { sel in
            // Reuse the existing channel detail for now — gives the
            // user the programme list + reminders + replay hooks.
            ChannelDetailView(channel: sel.channel, allChannels: channels)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: DS.Spacing.md) {
            // Explicit "Catégories" pill — focusable so the user has
            // an obvious way back when the focus engine has trapped
            // them inside the grid. Default-focused on appear so
            // pressing Up on any cell will always reach it within 1-2
            // hops.
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
            if let vm = epgViewModel, vm.isLoading {
                HStack(spacing: 6) {
                    ProgressView().tint(DS.Colour.textTertiary)
                    Text("\(vm.loadedCount)/\(vm.totalCount)")
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

    // MARK: - Time markers row

    private var timeMarkers: some View {
        ZStack(alignment: .topLeading) {
            // Empty corner above the channel column.
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: channelColumnWidth)
                Rectangle()
                    .fill(Color.white.opacity(0.04))
                    .frame(width: totalGridWidth)
            }

            // 30-min ticks. Every 30 minutes from gridStart.
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

            // Now indicator on the time markers — small triangle.
            Image(systemName: "arrowtriangle.down.fill")
                .font(.caption2)
                .foregroundColor(DS.Colour.accentWarm)
                .offset(
                    x: channelColumnWidth + position(for: Date()) - 6,
                    y: headerHeight - 16
                )
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
            // Row separator (subtle) so the eye can track horizontally.
            VStack(spacing: 0) {
                Spacer()
                Rectangle()
                    .fill(Color.white.opacity(0.04))
                    .frame(height: 1)
            }

            HStack(spacing: 0) {
                channelCell(channel)
                    .frame(width: channelColumnWidth, height: rowHeight)
                programGrid(channel)
                    .frame(width: totalGridWidth, height: rowHeight)
            }
        }
    }

    private func channelCell(_ channel: Channel) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            KFImage(URL(string: channel.displayIcon))
                .resizable()
                .placeholder {
                    Image(systemName: "tv")
                        .foregroundColor(DS.Colour.textTertiary)
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
                        .font(.system(size: 10, weight: .regular))
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
            // Row backdrop with vertical 30-min separators so the eye
            // can align titles with the time markers.
            ForEach(timeTicks.dropFirst(), id: \.self) { date in
                Rectangle()
                    .fill(Color.white.opacity(0.03))
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
                    .offset(x: position(for: date))
            }

            // Vertical "now" line — only inside the visible window.
            let nowX = position(for: Date())
            if nowX >= 0 && nowX <= totalGridWidth {
                Rectangle()
                    .fill(DS.Colour.accentWarm)
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
                    .offset(x: nowX)
            }

            // Programme cells.
            if let progs = epgViewModel?.epgData[channel.streamId] {
                ForEach(progs) { prog in
                    if let cell = layoutCell(for: prog) {
                        programCell(prog, channel: channel, layout: cell)
                            .frame(width: cell.width, height: rowHeight - 4)
                            .offset(x: cell.x, y: 2)
                    }
                }
            }
        }
        .frame(width: totalGridWidth, height: rowHeight)
    }

    /// Compute the on-screen position + width of a programme cell,
    /// clipped to the visible grid window. Returns nil when the
    /// programme falls entirely outside the grid.
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
                    .font(.system(size: 10, weight: .regular))
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

/// Pill style for the "Catégories" back button at the top of the
/// EPG grid. Same visual language as the sort chips on the Films /
/// Séries grids so the language stays consistent.
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
