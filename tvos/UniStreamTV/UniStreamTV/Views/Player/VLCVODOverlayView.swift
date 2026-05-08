import SwiftUI

/// SwiftUI overlay (Apple TV+ / Plex-style drawer) for the VLC VOD
/// player. Renders nothing when the drawer is hidden so UIPress
/// events flow uninterrupted to the parent UIKit VC; when shown,
/// sits as a bottom drawer with title / metadata / progress / a
/// row of focusable transport buttons.
///
/// Hosted by `VLCPlayerViewController` via a UIHostingController
/// child VC; see that file for the integration.
struct VLCVODOverlayView: View {
    @Bindable var model: VLCVODPlayerModel

    /// Default focus target when the drawer appears. Pulling focus
    /// onto play/pause means a single Select toggles playback.
    @FocusState private var focused: ButtonId?

    enum ButtonId: Hashable {
        case skipBack, playPause, skipForward
        case audio, subtitles, aspect, more
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.clear

            if model.isDrawerVisible {
                drawer
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(DS.Motion.standard, value: model.isDrawerVisible)
        // Default focus when drawer becomes visible. SwiftUI on tvOS
        // sometimes lands focus on the leftmost focusable; we want the
        // big play/pause to be the default since that's what 90% of
        // users actually press.
        .onChange(of: model.isDrawerVisible) { _, visible in
            if visible {
                // Defer one runloop so SwiftUI has materialised the
                // focusable buttons before we move focus onto one.
                DispatchQueue.main.async { focused = .playPause }
            } else {
                focused = nil
            }
        }
        // Each focus change inside the drawer counts as user activity —
        // tell the VC so it can re-arm its auto-hide timer. Without
        // this the drawer would vanish 5 s after appearance even while
        // the user is busy navigating buttons.
        .onChange(of: focused) { _, _ in
            model.onUserActivity()
        }
    }

    // MARK: - Drawer

    private var drawer: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            header
            progressBar
            buttonRow
        }
        .padding(.horizontal, DS.Padding.screenHorizontal)
        .padding(.top, DS.Spacing.xl)
        .padding(.bottom, DS.Spacing.xxl)
        .background(
            // Soft black gradient — clear at the top so the video
            // peeks through, opaque at the bottom for legibility.
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black.opacity(0.85), location: 0.45),
                    .init(color: .black.opacity(0.95), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        // Tell tvOS the drawer is one navigable focus region. Without
        // this hint the engine has been observed to refuse horizontal
        // traversal across the Spacer() between the transport cluster
        // and the audio/subs/more cluster.
        .focusSection()
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(model.title.cleanedTitleNoYear)
                    .font(DS.Typography.title1)
                    .foregroundColor(DS.Colour.textPrimary)
                    .lineLimit(1)
                if let subtitle = model.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(DS.Typography.body)
                        .foregroundColor(DS.Colour.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            timeReadout
        }
    }

    private var timeReadout: some View {
        HStack(spacing: DS.Spacing.xs) {
            Text(formatHMS(model.positionSeconds))
                .foregroundColor(DS.Colour.textPrimary)
            Text("/")
                .foregroundColor(DS.Colour.textTertiary)
            Text(formatHMS(model.durationSeconds))
                .foregroundColor(DS.Colour.textSecondary)
        }
        .font(.system(size: 18, weight: .medium, design: .monospaced))
    }

    // MARK: - Progress

    private var progressBar: some View {
        let fraction = model.durationSeconds > 0
            ? min(1, max(0, model.positionSeconds / model.durationSeconds))
            : 0
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.18))
                Capsule()
                    .fill(DS.Colour.accent)
                    .frame(width: geo.size.width * CGFloat(fraction))
                // Scrub head — small dot at the playback position.
                Circle()
                    .fill(.white)
                    .frame(width: 16, height: 16)
                    .offset(x: geo.size.width * CGFloat(fraction) - 8)
                    .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
            }
        }
        .frame(height: 8)
    }

    // MARK: - Buttons

    private var buttonRow: some View {
        HStack(spacing: DS.Spacing.lg) {
            transportButton(id: .skipBack, icon: "gobackward.15", label: "−15 s") {
                model.onSeek(-15)
            }
            transportButton(
                id: .playPause,
                icon: model.isPlaying ? "pause.fill" : "play.fill",
                label: model.isPlaying ? "Pause" : "Lecture",
                big: true
            ) {
                model.onPlayPause()
            }
            transportButton(id: .skipForward, icon: "goforward.30", label: "+30 s") {
                model.onSeek(30)
            }

            Spacer()

            transportButton(id: .audio, icon: "speaker.wave.2.fill", label: "Audio") {
                model.onShowAudioPicker()
            }
            transportButton(id: .subtitles, icon: "captions.bubble", label: "Sous-titres") {
                model.onShowSubtitlePicker()
            }
            transportButton(id: .aspect, icon: "aspectratio", label: model.aspectRatioLabel) {
                model.onCycleAspect()
            }
            transportButton(id: .more, icon: "ellipsis.circle", label: "Plus") {
                model.onShowMore()
            }
        }
    }

    @ViewBuilder
    private func transportButton(
        id: ButtonId,
        icon: String,
        label: String,
        big: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        let isFocused = focused == id

        Button(action: action) {
            VStack(spacing: DS.Spacing.xxs) {
                ZStack {
                    Circle()
                        .fill(big ? DS.Colour.accent : Color.white.opacity(isFocused ? 0.18 : 0.10))
                        .frame(width: big ? 76 : 56, height: big ? 76 : 56)
                    Image(systemName: icon)
                        .font(.system(size: big ? 30 : 22, weight: .semibold))
                        .foregroundColor(.white)
                }
                Text(label)
                    .font(DS.Typography.caption)
                    .foregroundColor(isFocused ? DS.Colour.textPrimary : DS.Colour.textSecondary)
            }
        }
        .buttonStyle(.plain)
        .focused($focused, equals: id)
        // Suppress the system focus halo (the wide pale-grey rounded
        // backdrop tvOS draws around any focused Button by default) —
        // we already paint our own focus state via accent fill +
        // scaleEffect, so the halo just looked dirty around them.
        .focusEffectDisabled()
        .scaleEffect(isFocused ? 1.10 : 1.0)
        .animation(DS.Focus.animation, value: isFocused)
    }

    // MARK: - Helpers

    private func formatHMS(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "--:--" }
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}
