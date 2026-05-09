import SwiftUI

/// Confirm dialog shown before resuming a VOD with non-trivial progress.
///
/// Two big focusable cards (Reprendre / Recommencer) plus a quiet
/// Annuler text button below. The presenting flow lives in
/// `PlayerPresenter.presentResumeConfirm` which hosts this in a
/// `UIHostingController` over the current top VC.
struct ResumeConfirmView: View {
    let title: String?
    let positionMs: Int
    let durationMs: Int?
    let onResume: () -> Void
    let onRestart: () -> Void
    let onCancel: () -> Void

    @FocusState private var focused: Action?

    enum Action: Hashable { case resume, restart, cancel }

    private var formattedPosition: String {
        Self.formatHMS(seconds: positionMs / 1000)
    }

    private var progressFraction: Double? {
        guard let durMs = durationMs, durMs > 0 else { return nil }
        return min(1.0, Double(positionMs) / Double(durMs))
    }

    private var progressLabel: String? {
        guard let f = progressFraction else { return nil }
        let pct = Int(round(f * 100))
        return "\(pct)% vu"
    }

    var body: some View {
        ZStack {
            // Dim the underlying player / detail view so the dialog
            // reads as a proper modal — `.overFullScreen` presentation
            // doesn't dim by itself.
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: DS.Spacing.xl) {
                VStack(spacing: DS.Spacing.xs) {
                    Text("Reprendre la lecture ?")
                        .font(DS.Typography.title1)
                        .foregroundColor(DS.Colour.textPrimary)
                    if let title {
                        Text(title)
                            .font(DS.Typography.body)
                            .foregroundColor(DS.Colour.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 16))
                        Text(formattedPosition)
                            .font(DS.Typography.bodyEmphasised)
                        if let progressLabel {
                            Text("·").foregroundColor(DS.Colour.textTertiary)
                            Text(progressLabel)
                        }
                    }
                    .foregroundColor(DS.Colour.accentLight)
                    .padding(.top, DS.Spacing.xs)
                }
                .padding(.bottom, DS.Spacing.sm)

                HStack(spacing: DS.Spacing.lg) {
                    actionCard(
                        action: .restart,
                        icon: "arrow.counterclockwise",
                        title: "Recommencer",
                        subtitle: "Depuis le début",
                        accent: false,
                        onTap: onRestart
                    )
                    actionCard(
                        action: .resume,
                        icon: "play.fill",
                        title: "Reprendre",
                        subtitle: "à \(formattedPosition)",
                        accent: true,
                        onTap: onResume
                    )
                }

                Text("Annuler")
                    .font(DS.Typography.body)
                    .foregroundColor(focused == .cancel ? DS.Colour.textPrimary : DS.Colour.textSecondary)
                    .padding(.vertical, DS.Spacing.sm)
                    .padding(.horizontal, DS.Spacing.lg)
                    .background(
                        Capsule().fill(focused == .cancel ? Color.white.opacity(0.15) : Color.clear)
                    )
                    .focusable()
                    .focused($focused, equals: .cancel)
                    .onTapGesture { onCancel() }
            }
            .padding(DS.Spacing.huge)
            .frame(maxWidth: 1100)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.hero, style: .continuous)
                    .fill(DS.Colour.surface)
                    .shadow(color: .black.opacity(0.6), radius: 40, y: 20)
            )
            .padding(DS.Padding.screenHorizontal)
        }
        .defaultFocus($focused, .resume)
        // Belt-and-braces against the tvOS system focus halo: the
        // per-Button `.focusEffectDisabled()` modifiers below proved
        // insufficient inside a UIHostingController, so apply it at
        // the body root for the entire dialog tree.
        .focusEffectDisabled()
        // Menu/Back must close just the dialog, not the whole player
        // underneath. Without this, the press propagates up to the
        // presenting VC and dismisses it too.
        .onExitCommand { onCancel() }
    }

    @ViewBuilder
    private func actionCard(
        action: Action,
        icon: String,
        title: String,
        subtitle: String,
        accent: Bool,
        onTap: @escaping () -> Void
    ) -> some View {
        // We deliberately drop SwiftUI `Button` here — on tvOS, even
        // `.buttonStyle(.plain)` keeps drawing the system focus halo
        // and `.focusEffectDisabled()` is consistently ignored once we
        // host the dialog inside a UIHostingController. A focusable
        // view + onTapGesture has no system halo to start with, so our
        // own scaleEffect / accent fill / ring carry the focus state
        // cleanly.
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 44, weight: .semibold))
            Text(title)
                .font(DS.Typography.title2)
            Text(subtitle)
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colour.textSecondary)
        }
        .frame(width: 320, height: 220)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .fill(accent ? DS.Colour.accent : DS.Colour.surfaceElevated)
        )
        .foregroundColor(.white)
        .focusable()
        .focused($focused, equals: action)
        .focusCardEffect(isFocused: focused == action)
        .onTapGesture { onTap() }
    }

    /// Format an integer number of seconds as `H:MM:SS` (≥1h) or `M:SS`.
    private static func formatHMS(seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}
