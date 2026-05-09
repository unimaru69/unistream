import SwiftUI

/// Generic radio-list track picker used by both the VLC live and VOD
/// player overlays in place of nested UIAlertControllers, which read
/// as small phone-style modals out of place on the big screen.
///
/// Two columns of focusable rows on tvOS — left-aligned label, optional
/// secondary detail (codec, channel count) on the right, a single dot
/// to mark the current selection. Default focus lands on the current
/// selection so the user can confirm with one click.
///
/// The presenting flow lives in `UIViewController.presentTrackPicker(...)`.
struct TrackPickerView: View {
    struct Option: Identifiable, Hashable {
        /// VLC track id. -1 is reserved for the "Désactivés" subtitle
        /// option synthesised by the picker.
        let id: Int32
        let label: String
        /// Optional sub-title shown right of the label — channel count,
        /// codec, etc. Empty / nil hides it.
        let detail: String?
    }

    let title: String
    let options: [Option]
    /// Current selection. -1 = subtitles disabled.
    let selectedId: Int32
    /// When true, an extra "Désactivés" row with id `-1` is prepended.
    /// Used by subtitle pickers; ignored by audio.
    let allowOff: Bool
    let onSelect: (Int32) -> Void
    let onDismiss: () -> Void

    @FocusState private var focused: Int32?
    /// Phantom-tap filter — see VLCVODOverlayView.
    @State private var lastFocusArrivedAt: Date = .distantPast
    private static let phantomTapWindow: TimeInterval = 0.25

    /// Effective option list with synthetic "Désactivés" prepended when
    /// `allowOff` is true.
    private var rows: [Option] {
        var out: [Option] = []
        if allowOff {
            out.append(Option(id: -1, label: "Désactivés", detail: nil))
        }
        out.append(contentsOf: options)
        return out
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack {
                    Text(title)
                        .font(DS.Typography.title2)
                        .foregroundColor(DS.Colour.textPrimary)
                    Spacer()
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(focused == Int32.max ? .white : DS.Colour.textTertiary)
                        .focusable()
                        .focused($focused, equals: Int32.max)
                        .onTapGesture {
                            let elapsed = Date().timeIntervalSince(lastFocusArrivedAt)
                            guard elapsed > Self.phantomTapWindow else { return }
                            onDismiss()
                        }
                }
                .padding(.bottom, DS.Spacing.sm)

                ScrollView {
                    LazyVStack(spacing: DS.Spacing.xxs) {
                        ForEach(rows) { row in
                            optionRow(row)
                        }
                    }
                }
                .frame(maxHeight: 720)
            }
            .padding(DS.Spacing.xl)
            .frame(width: 800)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.hero, style: .continuous)
                    .fill(DS.Colour.surface)
                    .shadow(color: .black.opacity(0.6), radius: 40, y: 20)
            )
        }
        .defaultFocus($focused, selectedId)
        // Stamp focus arrivals so the phantom-tap filter on each row
        // can distinguish a genuine Select press from a synthetic
        // tap fired during focus traversal on certain remotes.
        .onChange(of: focused) { _, newValue in
            if newValue != nil {
                lastFocusArrivedAt = Date()
            }
        }
        // Menu / Back closes just the picker, not the underlying
        // player.
        .onExitCommand { onDismiss() }
    }

    @ViewBuilder
    private func optionRow(_ option: Option) -> some View {
        let isSelected = option.id == selectedId
        let isFocused = focused == option.id

        // focusable + onTapGesture (no system halo) with phantom-tap
        // filter — see VLCVODOverlayView for the rationale.
        HStack(spacing: DS.Spacing.md) {
            ZStack {
                Circle()
                    .stroke(DS.Colour.textTertiary, lineWidth: 2)
                    .frame(width: 22, height: 22)
                if isSelected {
                    Circle()
                        .fill(DS.Colour.accent)
                        .frame(width: 12, height: 12)
                }
            }
            Text(option.label)
                .font(DS.Typography.body)
                .foregroundColor(.white)
            Spacer()
            if let detail = option.detail, !detail.isEmpty {
                Text(detail)
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colour.textSecondary)
            }
        }
        .padding(.vertical, DS.Spacing.sm)
        .padding(.horizontal, DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .fill(isFocused ? DS.Colour.surfaceElevated : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .strokeBorder(
                    DS.Colour.accent.opacity(isFocused ? 0.7 : 0),
                    lineWidth: DS.Focus.ringWidth
                )
        )
        .focusable()
        .focused($focused, equals: option.id)
        .onTapGesture {
            let elapsed = Date().timeIntervalSince(lastFocusArrivedAt)
            guard elapsed > Self.phantomTapWindow else { return }
            onSelect(option.id)
        }
    }
}

// MARK: - UIKit presentation helper

import UIKit

extension UIViewController {
    /// Present `TrackPickerView` over this VC. The picker dismisses
    /// itself on selection or cancel; the supplied closures fire after
    /// the dismiss animation completes.
    func presentTrackPicker(
        title: String,
        options: [TrackPickerView.Option],
        selectedId: Int32,
        allowOff: Bool,
        onSelect: @escaping (Int32) -> Void
    ) {
        // Wrapper holds the hosting controller so the SwiftUI closures
        // can dismiss themselves — see PlayerPresenter for the same
        // pattern around `Holder`.
        final class Holder { weak var hosting: UIViewController? }
        let holder = Holder()

        let view = TrackPickerView(
            title: title,
            options: options,
            selectedId: selectedId,
            allowOff: allowOff,
            onSelect: { id in
                holder.hosting?.dismiss(animated: true) { onSelect(id) }
            },
            onDismiss: {
                holder.hosting?.dismiss(animated: true)
            }
        )

        let hosting = UIHostingController(rootView: view)
        hosting.modalPresentationStyle = .overFullScreen
        hosting.modalTransitionStyle = .crossDissolve
        hosting.view.backgroundColor = .clear
        holder.hosting = hosting
        present(hosting, animated: true)
    }
}
