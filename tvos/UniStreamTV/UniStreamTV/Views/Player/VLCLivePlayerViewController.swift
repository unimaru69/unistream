import Kingfisher
import UIKit
import VLCKitSPM

/// VLC-based live TV player with channel zapping and transport overlay.
final class VLCLivePlayerViewController: UIViewController {

    // Subtitle font size — see VLCPlayerViewController for the rationale.
    // Pass the freetype-rel-fontsize enum at libvlc-instance level via
    // `VLCMediaPlayer(options:)`; it's silently ignored at media level.
    private let mediaPlayer = VLCMediaPlayer(options: [
        "--freetype-rel-fontsize=20",
    ])
    private var channels: [Channel]
    private var currentIndex: Int
    private let api: XtreamAPIService
    private let timeshiftAllowed: Bool

    // Live timeshift state.
    // offset == 0 : live HLS. offset > 0 : Xtream timeshift TS URL, `offset`
    // seconds behind the real-time edge of the stream.
    private var timeshiftOffsetSec: Int = 0
    // Start time (wall clock) of each arrow press — used to decide between a
    // short (10 s) and long (60 s) seek when the button is released.
    private var pressStart: [UIPress.PressType: TimeInterval] = [:]
    // Short / long press boundary (seconds).
    private let longPressThreshold: TimeInterval = 0.6
    private let shortSeekStep: Int = 10
    private let longSeekStep: Int = 60

    // Views
    private let videoView = UIView()
    /// Backdrop image of the current programme (TMDB-enriched) — sits
    /// between the video and the overlay so that when the overlay shows,
    /// it crossfades into a "Plex-style" themed scene that's clearly
    /// distinct from the raw video. Kept transparent when no image is
    /// available so we don't dim the live image for nothing.
    private let backdropImageView = UIImageView()
    private let backdropDimView = UIView()
    private let overlayView = UIView()
    private let channelNameLabel = UILabel()
    private let channelNumberLabel = UILabel()
    private let liveBadge = UILabel()
    private let clockLabel = UILabel()
    /// Current programme — title + start/end times. Hidden when the
    /// EPG cache has nothing for the current channel.
    private let programmeTitleLabel = UILabel()
    private let programmeTimeLabel = UILabel()
    /// Programme progress bar — mirrors what LiveFocusedPreview shows
    /// in the channel grid, but here it sits in the player overlay so
    /// the user can tell at a glance where they are inside the live
    /// programme without leaving the channel.
    private let programmeProgressBar = UIProgressView(progressViewStyle: .default)
    private let nextProgrammeLabel = UILabel()
    private let playPauseIcon = UIImageView()

    /// Token cancelled when the channel changes — prevents a slow TMDB
    /// fetch for channel A from clobbering the overlay after the user
    /// has zapped to channel B.
    private var currentEnrichmentTask: Task<Void, Never>?
    /// Same idea for the EPG fetch — the player VC may be the first
    /// place to need EPG for the channel (the global EPGCache is only
    /// populated by EPGGridView and ChannelGridView's first 30 cards),
    /// so we fall back to a direct API fetch.
    private var currentEpgFetchTask: Task<Void, Never>?
    /// Per-channel EPG snapshot we built ourselves when the global
    /// cache had nothing. Avoids re-fetching when the user zaps back
    /// and forth.
    private var localEpgByStreamId: [String: [EpgProgram]] = [:]

    // Zap overlay (large, centered, auto-hiding)
    private let zapChannelLabel = UILabel()
    private let zapChannelNumber = UILabel()

    private var hideOverlayTimer: Timer?
    private var clockTimer: Timer?
    private var zapHideTimer: Timer?

    init(channels: [Channel], startIndex: Int, api: XtreamAPIService, timeshiftAllowed: Bool = false) {
        self.channels = channels
        self.currentIndex = max(0, min(startIndex, channels.count - 1))
        self.api = api
        self.timeshiftAllowed = timeshiftAllowed
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupVideoView()
        setupBackdrop()
        setupOverlay()
        setupZapOverlay()
        setupGestures()
        loadCurrentChannel()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        mediaPlayer.play()
        showOverlay(autoHide: true)
        showZapOverlay()
        startClock()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        hideOverlayTimer?.invalidate()
        zapHideTimer?.invalidate()
        clockTimer?.invalidate()
        // NOTE: VLC teardown moved to viewDidDisappear. `mediaPlayer.stop()`
        // synchronously flushes the decoder queue and can briefly block the
        // main thread; running it during the dismiss animation leaves tvOS
        // with an orphaned responder chain → focus engine dies, Menu button
        // inert, the app appears frozen.
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        mediaPlayer.drawable = nil
        mediaPlayer.stop()
    }

    // MARK: - Setup

    private func setupVideoView() {
        videoView.frame = view.bounds
        videoView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        videoView.backgroundColor = .black
        view.addSubview(videoView)
        mediaPlayer.drawable = videoView
    }

    /// The backdrop image sits between the live video and the overlay,
    /// completely transparent until we fetch a TMDB still for the
    /// current programme. When available, crossfades in alongside the
    /// overlay (and out with it) so it never competes with the video
    /// itself.
    private func setupBackdrop() {
        backdropImageView.frame = view.bounds
        backdropImageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backdropImageView.contentMode = .scaleAspectFill
        backdropImageView.clipsToBounds = true
        backdropImageView.alpha = 0
        view.addSubview(backdropImageView)

        // A second dim layer over the backdrop so the foreground text
        // stays readable even when the still has bright tones.
        backdropDimView.frame = view.bounds
        backdropDimView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backdropDimView.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        backdropDimView.alpha = 0
        view.addSubview(backdropDimView)
    }

    private func setupOverlay() {
        overlayView.frame = view.bounds
        overlayView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlayView.backgroundColor = .clear
        overlayView.alpha = 0
        view.addSubview(overlayView)

        // Top gradient (black → transparent) built with a CAGradientLayer.
        let topGradientView = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 200))
        topGradientView.autoresizingMask = [.flexibleWidth]
        let topGradient = CAGradientLayer()
        topGradient.frame = topGradientView.bounds
        topGradient.colors = [UIColor.black.withAlphaComponent(0.75).cgColor, UIColor.clear.cgColor]
        topGradientView.layer.insertSublayer(topGradient, at: 0)
        overlayView.addSubview(topGradientView)
        overlayView.layer.sublayers?.first(where: { $0 is CAGradientLayer })?.frame = topGradientView.bounds

        // LIVE badge
        liveBadge.text = "  EN DIRECT  "
        liveBadge.font = .systemFont(ofSize: 16, weight: .bold)
        liveBadge.textColor = .white
        liveBadge.backgroundColor = UIColor(red: 0.85, green: 0.15, blue: 0.15, alpha: 1)
        liveBadge.layer.cornerRadius = 6
        liveBadge.layer.masksToBounds = true
        liveBadge.translatesAutoresizingMaskIntoConstraints = false
        overlayView.addSubview(liveBadge)

        // Channel name (big)
        channelNameLabel.font = .systemFont(ofSize: 38, weight: .bold)
        channelNameLabel.textColor = .white
        channelNameLabel.translatesAutoresizingMaskIntoConstraints = false
        overlayView.addSubview(channelNameLabel)

        // Channel number (N / total)
        channelNumberLabel.font = .systemFont(ofSize: 20, weight: .medium)
        channelNumberLabel.textColor = .white.withAlphaComponent(0.7)
        channelNumberLabel.translatesAutoresizingMaskIntoConstraints = false
        overlayView.addSubview(channelNumberLabel)

        // Current programme — title (large, plus emoji LIVE dot when
        // we know the show is on right now) and time range. Hidden
        // until the EPG cache yields a hit for the current channel.
        programmeTitleLabel.font = .systemFont(ofSize: 26, weight: .semibold)
        programmeTitleLabel.textColor = .white.withAlphaComponent(0.95)
        programmeTitleLabel.numberOfLines = 1
        programmeTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        programmeTitleLabel.isHidden = true
        overlayView.addSubview(programmeTitleLabel)

        programmeTimeLabel.font = .monospacedDigitSystemFont(ofSize: 16, weight: .regular)
        programmeTimeLabel.textColor = .white.withAlphaComponent(0.7)
        programmeTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        programmeTimeLabel.isHidden = true
        overlayView.addSubview(programmeTimeLabel)

        // Programme progress bar — orange-tinted to match the EN DIRECT
        // accent already used elsewhere in the live UI.
        programmeProgressBar.progressTintColor = UIColor(red: 1.0, green: 0.42, blue: 0.36, alpha: 1) // accentWarm
        programmeProgressBar.trackTintColor = .white.withAlphaComponent(0.2)
        programmeProgressBar.translatesAutoresizingMaskIntoConstraints = false
        programmeProgressBar.isHidden = true
        overlayView.addSubview(programmeProgressBar)

        // Next programme — small grey "Suite : …" line below.
        nextProgrammeLabel.font = .systemFont(ofSize: 15, weight: .regular)
        nextProgrammeLabel.textColor = .white.withAlphaComponent(0.55)
        nextProgrammeLabel.numberOfLines = 1
        nextProgrammeLabel.translatesAutoresizingMaskIntoConstraints = false
        nextProgrammeLabel.isHidden = true
        overlayView.addSubview(nextProgrammeLabel)

        // Clock (current time)
        clockLabel.font = .monospacedDigitSystemFont(ofSize: 26, weight: .medium)
        clockLabel.textColor = .white.withAlphaComponent(0.85)
        clockLabel.translatesAutoresizingMaskIntoConstraints = false
        overlayView.addSubview(clockLabel)

        // Play/Pause icon (shown briefly on state change)
        playPauseIcon.contentMode = .scaleAspectFit
        playPauseIcon.tintColor = .white
        playPauseIcon.alpha = 0
        playPauseIcon.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(playPauseIcon)

        NSLayoutConstraint.activate([
            // Top: channel name + number on the left, clock on the right
            liveBadge.topAnchor.constraint(equalTo: overlayView.safeAreaLayoutGuide.topAnchor, constant: 30),
            liveBadge.leadingAnchor.constraint(equalTo: overlayView.leadingAnchor, constant: 60),
            liveBadge.heightAnchor.constraint(equalToConstant: 30),

            channelNameLabel.topAnchor.constraint(equalTo: liveBadge.bottomAnchor, constant: 10),
            channelNameLabel.leadingAnchor.constraint(equalTo: overlayView.leadingAnchor, constant: 60),
            channelNameLabel.trailingAnchor.constraint(lessThanOrEqualTo: clockLabel.leadingAnchor, constant: -30),

            channelNumberLabel.topAnchor.constraint(equalTo: channelNameLabel.bottomAnchor, constant: 4),
            channelNumberLabel.leadingAnchor.constraint(equalTo: overlayView.leadingAnchor, constant: 60),

            // Programme block — title sits below the channel number, time
            // range below that, "Suite" line at the very bottom.
            programmeTitleLabel.topAnchor.constraint(equalTo: channelNumberLabel.bottomAnchor, constant: 14),
            programmeTitleLabel.leadingAnchor.constraint(equalTo: overlayView.leadingAnchor, constant: 60),
            programmeTitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: clockLabel.leadingAnchor, constant: -30),

            programmeTimeLabel.topAnchor.constraint(equalTo: programmeTitleLabel.bottomAnchor, constant: 4),
            programmeTimeLabel.leadingAnchor.constraint(equalTo: overlayView.leadingAnchor, constant: 60),

            programmeProgressBar.topAnchor.constraint(equalTo: programmeTimeLabel.bottomAnchor, constant: 8),
            programmeProgressBar.leadingAnchor.constraint(equalTo: overlayView.leadingAnchor, constant: 60),
            programmeProgressBar.widthAnchor.constraint(equalToConstant: 360),
            programmeProgressBar.heightAnchor.constraint(equalToConstant: 4),

            nextProgrammeLabel.topAnchor.constraint(equalTo: programmeProgressBar.bottomAnchor, constant: 8),
            nextProgrammeLabel.leadingAnchor.constraint(equalTo: overlayView.leadingAnchor, constant: 60),
            nextProgrammeLabel.trailingAnchor.constraint(lessThanOrEqualTo: clockLabel.leadingAnchor, constant: -30),

            clockLabel.topAnchor.constraint(equalTo: overlayView.safeAreaLayoutGuide.topAnchor, constant: 38),
            clockLabel.trailingAnchor.constraint(equalTo: overlayView.trailingAnchor, constant: -60),

            playPauseIcon.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            playPauseIcon.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            playPauseIcon.widthAnchor.constraint(equalToConstant: 120),
            playPauseIcon.heightAnchor.constraint(equalToConstant: 120),
        ])
    }

    private func setupZapOverlay() {
        zapChannelLabel.font = .systemFont(ofSize: 42, weight: .bold)
        zapChannelLabel.textColor = .white
        zapChannelLabel.textAlignment = .center
        zapChannelLabel.alpha = 0
        zapChannelLabel.layer.shadowColor = UIColor.black.cgColor
        zapChannelLabel.layer.shadowOffset = CGSize(width: 0, height: 2)
        zapChannelLabel.layer.shadowOpacity = 0.8
        zapChannelLabel.layer.shadowRadius = 8
        zapChannelLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(zapChannelLabel)

        zapChannelNumber.font = .systemFont(ofSize: 24, weight: .medium)
        zapChannelNumber.textColor = .white.withAlphaComponent(0.7)
        zapChannelNumber.textAlignment = .center
        zapChannelNumber.alpha = 0
        zapChannelNumber.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(zapChannelNumber)

        NSLayoutConstraint.activate([
            zapChannelLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            zapChannelLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 120),
            zapChannelLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 60),
            zapChannelLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -60),
            zapChannelNumber.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            zapChannelNumber.topAnchor.constraint(equalTo: zapChannelLabel.bottomAnchor, constant: 8),
        ])
    }

    // MARK: - Gestures

    private func setupGestures() {
        // Siri Remote touchpad swipes (zap). No effect on Free / Bose — button
        // handling below covers them.
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(zapNext))
        swipeLeft.direction = .left
        view.addGestureRecognizer(swipeLeft)

        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(zapPrev))
        swipeRight.direction = .right
        view.addGestureRecognizer(swipeRight)

        // Long press (any button) — options menu.
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        longPress.minimumPressDuration = 1.0
        view.addGestureRecognizer(longPress)

        // Play/Pause, Select, Menu and D-pad arrows → pressesBegan below.
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        // Modals (track picker, options alert) dismiss themselves —
        // intercepting Menu here would race their dismissal and
        // dismiss the player itself. See VLCPlayerViewController for
        // the same guard.
        if presentedViewController != nil {
            super.pressesBegan(presses, with: event)
            return
        }
        var handled = false
        let now = Date().timeIntervalSince1970
        for press in presses {
            switch press.type {
            case .menu:
                // Swallow on Began; dismiss on Ended (HIG).
                return
            case .select:
                toggleOverlay()
                handled = true
            case .upArrow, .pageUp:
                zapNext()
                handled = true
            case .downArrow, .pageDown:
                zapPrev()
                handled = true
            case .leftArrow, .rightArrow:
                // Record press start; actual seek fires on pressesEnded so we
                // can measure short (10 s) vs long (60 s) press duration.
                pressStart[press.type] = now
                handled = true
            case .playPause:
                togglePlayPause()
                handled = true
            default:
                // External keyboard fallback.
                if let key = press.key {
                    switch key.keyCode {
                    case .keyboardUpArrow, .keyboardPageUp: zapNext(); handled = true
                    case .keyboardDownArrow, .keyboardPageDown: zapPrev(); handled = true
                    case .keyboardLeftArrow:
                        pressStart[.leftArrow] = now; handled = true
                    case .keyboardRightArrow:
                        pressStart[.rightArrow] = now; handled = true
                    case .keyboardReturnOrEnter, .keyboardSpacebar: toggleOverlay(); handled = true
                    default: break
                    }
                }
            }
        }
        if !handled { super.pressesBegan(presses, with: event) }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if presentedViewController != nil {
            super.pressesEnded(presses, with: event)
            return
        }
        var handled = false
        let now = Date().timeIntervalSince1970
        for press in presses {
            if press.type == .menu {
                // Dismiss only — VLC teardown happens in viewDidDisappear so
                // stop() never blocks main thread during the transition.
                dismiss(animated: true)
                return
            }
            // Map keyboard arrows to their corresponding remote press type so
            // both external keyboards and IR remotes share the same timing key.
            let mapped: UIPress.PressType? = {
                switch press.type {
                case .leftArrow, .rightArrow: return press.type
                default:
                    if let kc = press.key?.keyCode {
                        if kc == .keyboardLeftArrow { return .leftArrow }
                        if kc == .keyboardRightArrow { return .rightArrow }
                    }
                    return nil
                }
            }()
            if let t = mapped, let start = pressStart.removeValue(forKey: t) {
                let duration = now - start
                let step = duration >= longPressThreshold ? longSeekStep : shortSeekStep
                // ← = go back in time (offset +), → = go forward (offset -).
                timeshiftSeek(delta: t == .leftArrow ? +step : -step)
                handled = true
            }
        }
        if !handled { super.pressesEnded(presses, with: event) }
    }

    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            if press.type == .menu { return }
            pressStart.removeValue(forKey: press.type)
        }
        super.pressesCancelled(presses, with: event)
    }

    // MARK: - Actions

    @objc private func togglePlayPause() {
        if mediaPlayer.isPlaying {
            mediaPlayer.pause()
            flashPlayPauseIcon(playing: false)
        } else {
            mediaPlayer.play()
            flashPlayPauseIcon(playing: true)
        }
        showOverlay(autoHide: true)
    }

    @objc private func toggleOverlay() {
        if overlayView.alpha > 0 {
            hideOverlay()
        } else {
            showOverlay(autoHide: true)
        }
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        showPlaybackOptions()
    }

    private func showPlaybackOptions() {
        let alert = UIAlertController(
            title: "Options",
            message: "↑ ↓ Chaîne suivante/précédente · Menu Retour",
            preferredStyle: .actionSheet
        )

        // Audio tracks
        let audioCount = Int(mediaPlayer.numberOfAudioTracks)
        if audioCount > 1 {
            alert.addAction(UIAlertAction(title: "🔊 Piste audio…", style: .default) { [weak self] _ in
                self?.showAudioPicker()
            })
        }

        // Subtitle tracks
        let subCount = Int(mediaPlayer.numberOfSubtitlesTracks)
        if subCount > 0 {
            alert.addAction(UIAlertAction(title: "💬 Sous-titres…", style: .default) { [weak self] _ in
                self?.showSubtitlePicker()
            })
        }

        // Aspect ratio
        alert.addAction(UIAlertAction(title: "📐 Format d'image", style: .default) { [weak self] _ in
            self?.cycleAspectRatio()
        })

        alert.addAction(UIAlertAction(title: "Fermer", style: .cancel))
        present(alert, animated: true)
    }

    private func showAudioPicker() {
        let names = mediaPlayer.audioTrackNames as? [String] ?? []
        let ids = mediaPlayer.audioTrackIndexes as? [NSNumber] ?? []
        let options: [TrackPickerView.Option] = zip(names, ids).map { name, id in
            TrackPickerView.Option(id: id.int32Value, label: name, detail: nil)
        }
        presentTrackPicker(
            title: "Piste audio",
            options: options,
            selectedId: mediaPlayer.currentAudioTrackIndex,
            allowOff: false
        ) { [weak self] id in
            self?.mediaPlayer.currentAudioTrackIndex = id
        }
    }

    private func showSubtitlePicker() {
        let names = mediaPlayer.videoSubTitlesNames as? [String] ?? []
        let ids = mediaPlayer.videoSubTitlesIndexes as? [NSNumber] ?? []
        let options: [TrackPickerView.Option] = zip(names, ids).map { name, id in
            TrackPickerView.Option(id: id.int32Value, label: name, detail: nil)
        }
        presentTrackPicker(
            title: "Sous-titres",
            options: options,
            selectedId: mediaPlayer.currentVideoSubTitleIndex,
            allowOff: true
        ) { [weak self] id in
            self?.mediaPlayer.currentVideoSubTitleIndex = id
        }
    }

    private func cycleAspectRatio() {
        // VLC aspect ratios: nil (default), "16:9", "4:3", "1:1", "16:10", "2.21:1", "2.35:1", "5:4"
        let ratios: [(String?, String)] = [
            (nil, "Auto"),
            ("16:9", "16:9"),
            ("4:3", "4:3"),
            ("1:1", "1:1"),
        ]
        let current = mediaPlayer.videoAspectRatio.map { String(cString: $0) }
        let currentIdx = ratios.firstIndex(where: { $0.0 == current }) ?? 0
        let nextIdx = (currentIdx + 1) % ratios.count
        let (next, _) = ratios[nextIdx]
        if let next {
            next.withCString { cstr in
                mediaPlayer.videoAspectRatio = UnsafeMutablePointer(mutating: cstr)
            }
        } else {
            mediaPlayer.videoAspectRatio = nil
        }
    }

    // MARK: - Zapping

    @objc private func zapNext() { zap(delta: 1) }
    @objc private func zapPrev() { zap(delta: -1) }

    private func zap(delta: Int) {
        guard !channels.isEmpty else { return }
        currentIndex = (currentIndex + delta + channels.count) % channels.count
        // Zapping always jumps back to live on the new channel.
        timeshiftOffsetSec = 0
        loadCurrentChannel()
        showZapOverlay()
        updateOverlayForCurrentChannel()
        showOverlay(autoHide: true)
    }

    private func loadCurrentChannel() {
        if timeshiftOffsetSec > 0 {
            loadTimeshiftStream()
        } else {
            loadLiveStream()
        }
        updateOverlayForCurrentChannel()
    }

    private func loadLiveStream() {
        let channel = channels[currentIndex]
        guard let url = api.liveStreamUrl(streamId: channel.streamId) else { return }
        let media = VLCMedia(url: url)
        media.addOptions([
            "network-caching": 1500,
            "live-caching": 1500,
        ])
        mediaPlayer.media = media
        mediaPlayer.play()
    }

    private func loadTimeshiftStream() {
        let channel = channels[currentIndex]
        let startUtc = Date().addingTimeInterval(-Double(timeshiftOffsetSec))
        // Cover enough forward window so the stream keeps playing toward live
        // without us having to chain reloads. Cap at archive length.
        let bufferMinutes = max(30, (timeshiftOffsetSec / 60) + 30)
        let cappedMinutes = min(bufferMinutes, max(60, channel.archiveDays * 24 * 60))
        guard let url = api.timeshiftUrl(
            streamId: channel.streamId,
            startUtc: startUtc,
            durationMinutes: cappedMinutes
        ) else { return }
        let media = VLCMedia(url: url)
        media.addOptions([
            "network-caching": 3000,
            "file-caching": 3000,
        ])
        mediaPlayer.media = media
        mediaPlayer.play()
    }

    // MARK: - Timeshift

    /// Positive delta goes **backward** in time (further from live).
    /// Negative delta goes **forward** (closer to live). When offset reaches 0
    /// we reload the live HLS URL.
    private func timeshiftSeek(delta: Int) {
        let channel = channels[currentIndex]

        guard timeshiftAllowed else {
            flashCenterMessage("Replay réservé à l'abonnement Premium")
            return
        }
        guard channel.hasCatchup, channel.archiveDays > 0 else {
            flashCenterMessage("Replay indisponible sur cette chaîne")
            return
        }

        let maxOffsetSec = channel.archiveDays * 24 * 60 * 60
        let newOffset = max(0, min(maxOffsetSec, timeshiftOffsetSec + delta))
        guard newOffset != timeshiftOffsetSec else {
            // Already at the edge (live or max archive).
            flashCenterMessage(newOffset == 0 ? "Vous êtes en direct" : "Limite du replay atteinte")
            return
        }

        timeshiftOffsetSec = newOffset
        if newOffset == 0 {
            loadLiveStream()
            flashCenterMessage("● En direct")
        } else {
            loadTimeshiftStream()
            flashCenterMessage("↩ \(formatOffset(newOffset))")
        }
        updateOverlayForCurrentChannel()
    }

    private func formatOffset(_ sec: Int) -> String {
        if sec < 60 { return "-\(sec) s" }
        let m = sec / 60, s = sec % 60
        let h = m / 60, mm = m % 60
        if h > 0 { return "-\(h) h \(mm) min" }
        if s == 0 { return "-\(m) min" }
        return "-\(m) min \(s) s"
    }

    private func updateOverlayForCurrentChannel() {
        let channel = channels[currentIndex]
        channelNameLabel.text = channel.name
        channelNumberLabel.text = "Chaîne \(currentIndex + 1) / \(channels.count)"
        updateLiveBadge()
        refreshProgrammeAndBackdrop(for: channel)
    }

    /// Look up the current + next programme from `EPGCache`, falling
    /// back to a direct API fetch if the cache is empty (which is the
    /// usual state when the player is launched from a channel the
    /// grid hadn't pre-loaded EPG for). Updates the overlay labels
    /// and kicks off a TMDB enrichment in the background to fetch a
    /// backdrop still — best-effort, news / regional shows won't
    /// match TMDB.
    private func refreshProgrammeAndBackdrop(for channel: Channel) {
        // Cancel stale tasks from the previous channel.
        currentEnrichmentTask?.cancel()
        currentEnrichmentTask = nil
        currentEpgFetchTask?.cancel()
        currentEpgFetchTask = nil

        // Reset visible state — never carry the old programme over.
        programmeTitleLabel.isHidden = true
        programmeTimeLabel.isHidden = true
        programmeProgressBar.isHidden = true
        nextProgrammeLabel.isHidden = true
        UIView.animate(withDuration: 0.25) {
            self.backdropImageView.alpha = 0
            self.backdropDimView.alpha = 0
        }
        backdropImageView.image = nil

        // 1) Global EPGCache (populated by EPGGridView / first 30 of
        //    a category in ChannelGridView).
        if let cache = PlayerPresenter.epgCache,
           let programmes = cache.programs(for: channel.streamId, day: Date()),
           !programmes.isEmpty {
            applyProgrammes(programmes, channel: channel)
            return
        }
        // 2) Local snapshot — already fetched ourselves earlier this
        //    session (e.g. user zaps back to a channel they zapped
        //    away from).
        if let programmes = localEpgByStreamId[channel.streamId], !programmes.isEmpty {
            applyProgrammes(programmes, channel: channel)
            return
        }
        // 3) Direct API fetch — last resort, but the most common path
        //    when the player launches a channel cold.
        currentEpgFetchTask = Task { [weak self] in
            guard let self else { return }
            do {
                let programmes = try await self.api.getShortEpg(streamId: channel.streamId, limit: 8)
                guard !Task.isCancelled else { return }
                await MainActor.run { [weak self] in
                    guard let self, !Task.isCancelled else { return }
                    self.localEpgByStreamId[channel.streamId] = programmes
                    if !programmes.isEmpty {
                        self.applyProgrammes(programmes, channel: channel)
                    }
                }
            } catch {
                // Silent — channel just won't show programme info.
            }
        }
    }

    /// Push a freshly-resolved programme list into the overlay
    /// labels + progress bar, and kick off the TMDB backdrop fetch
    /// for the current programme.
    private func applyProgrammes(_ programmes: [EpgProgram], channel: Channel) {
        let now = Date()
        let current = programmes.first(where: {
            ($0.start ?? .distantFuture) <= now && ($0.end ?? .distantPast) > now
        })
        let next = programmes.first(where: { ($0.start ?? .distantPast) > now })

        if let current {
            programmeTitleLabel.text = current.title
            programmeTimeLabel.text = formatProgrammeTime(start: current.start, end: current.end)
            programmeTitleLabel.isHidden = false
            programmeTimeLabel.isHidden = false
            programmeProgressBar.setProgress(Float(current.progress), animated: false)
            programmeProgressBar.isHidden = false

            // TMDB backdrop fetch — best-effort.
            let title = current.title
            currentEnrichmentTask = Task { [weak self] in
                guard let result = await TMDBService.shared.enrich(rawTitle: title, kind: .tv) else { return }
                guard let url = result.backdropURL(size: "w1280") else { return }
                await MainActor.run {
                    guard let self, !Task.isCancelled else { return }
                    self.loadBackdrop(url: url)
                }
            }
        }

        if let next {
            let nextTime = formatProgrammeTime(start: next.start, end: nil) ?? ""
            nextProgrammeLabel.text = "Suite — \(nextTime) \(next.title)"
            nextProgrammeLabel.isHidden = false
        }
    }

    private func loadBackdrop(url: URL) {
        // Kingfisher handles the cache + decode + main-thread set.
        // We fade-in only if the overlay is currently visible — the
        // `showOverlay` / `hideOverlay` pair handles the full fade.
        backdropImageView.kf.setImage(with: url) { [weak self] _ in
            guard let self else { return }
            if self.overlayView.alpha > 0 {
                UIView.animate(withDuration: 0.4) {
                    self.backdropImageView.alpha = 1
                    self.backdropDimView.alpha = 1
                }
            }
        }
    }

    /// "20:30 – 22:00" when both bounds are known; "20:30" when only
    /// start is known; nil when neither.
    private func formatProgrammeTime(start: Date?, end: Date?) -> String? {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        switch (start, end) {
        case (let s?, let e?): return "\(f.string(from: s)) – \(f.string(from: e))"
        case (let s?, nil):    return f.string(from: s)
        default:               return nil
        }
    }

    /// Swap the top-left badge between "EN DIRECT" (red) and "REPLAY" (orange)
    /// depending on whether the user is currently timeshifting.
    private func updateLiveBadge() {
        if timeshiftOffsetSec == 0 {
            liveBadge.text = "  EN DIRECT  "
            liveBadge.backgroundColor = UIColor(red: 0.85, green: 0.15, blue: 0.15, alpha: 1)
        } else {
            liveBadge.text = "  ↩ REPLAY \(formatOffset(timeshiftOffsetSec))  "
            liveBadge.backgroundColor = UIColor(red: 0.95, green: 0.55, blue: 0.10, alpha: 1)
        }
    }

    /// Briefly show a large centered message (uses the zap overlay labels).
    /// Overrides any in-flight zap overlay — acceptable because seek and zap are
    /// mutually exclusive user gestures.
    private func flashCenterMessage(_ message: String) {
        zapChannelLabel.text = message
        zapChannelNumber.text = ""
        UIView.animate(withDuration: 0.15) {
            self.zapChannelLabel.alpha = 1
            self.zapChannelNumber.alpha = 0
        }
        zapHideTimer?.invalidate()
        zapHideTimer = Timer.scheduledTimer(withTimeInterval: 1.8, repeats: false) { [weak self] _ in
            Task { @MainActor in
                UIView.animate(withDuration: 0.4) {
                    self?.zapChannelLabel.alpha = 0
                }
            }
        }
    }

    // MARK: - Overlays

    private func showOverlay(autoHide: Bool) {
        let hasBackdrop = backdropImageView.image != nil
        UIView.animate(withDuration: 0.25) {
            self.overlayView.alpha = 1
            if hasBackdrop {
                self.backdropImageView.alpha = 1
                self.backdropDimView.alpha = 1
            }
        }
        if autoHide {
            hideOverlayTimer?.invalidate()
            hideOverlayTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: false) { [weak self] _ in
                Task { @MainActor in self?.hideOverlay() }
            }
        }
    }

    private func hideOverlay() {
        hideOverlayTimer?.invalidate()
        UIView.animate(withDuration: 0.4) {
            self.overlayView.alpha = 0
            self.backdropImageView.alpha = 0
            self.backdropDimView.alpha = 0
        }
    }

    private func showZapOverlay() {
        let channel = channels[currentIndex]
        zapChannelLabel.text = channel.name
        zapChannelNumber.text = "\(currentIndex + 1) / \(channels.count)"
        UIView.animate(withDuration: 0.2) {
            self.zapChannelLabel.alpha = 1
            self.zapChannelNumber.alpha = 1
        }
        zapHideTimer?.invalidate()
        zapHideTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { [weak self] _ in
            Task { @MainActor in
                UIView.animate(withDuration: 0.5) {
                    self?.zapChannelLabel.alpha = 0
                    self?.zapChannelNumber.alpha = 0
                }
            }
        }
    }

    private func flashPlayPauseIcon(playing: Bool) {
        let symbol = playing ? "play.fill" : "pause.fill"
        playPauseIcon.image = UIImage(systemName: symbol)?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 120, weight: .bold))
        playPauseIcon.alpha = 1
        UIView.animate(withDuration: 0.6, delay: 0.3) {
            self.playPauseIcon.alpha = 0
        }
    }

    // MARK: - Clock

    private func startClock() {
        updateClock()
        clockTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateClock() }
        }
    }

    private func updateClock() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        clockLabel.text = formatter.string(from: Date())

        // Roll the programme progress bar forward as time advances —
        // the EpgProgram.progress is computed on read, so we just
        // re-query the cache and push the new value. Try the global
        // EPGCache first, fall back to the local snapshot we built
        // from a direct API fetch.
        guard !programmeProgressBar.isHidden else { return }
        let channel = channels[currentIndex]
        let now = Date()
        let programmes: [EpgProgram]? = {
            if let cache = PlayerPresenter.epgCache,
               let cached = cache.programs(for: channel.streamId, day: Date()) {
                return cached
            }
            return localEpgByStreamId[channel.streamId]
        }()
        if let programmes,
           let current = programmes.first(where: {
            ($0.start ?? .distantFuture) <= now && ($0.end ?? .distantPast) > now
        }) {
            programmeProgressBar.setProgress(Float(current.progress), animated: true)
        }
    }
}
