import UIKit
import VLCKitSPM

/// VLC-based player for formats AVPlayer can't handle (MKV, AVI, etc.).
/// Presented as a full-screen UIViewController with basic transport controls.
final class VLCPlayerViewController: UIViewController {

    private let mediaPlayer = VLCMediaPlayer()
    private let url: URL
    private let videoTitle: String
    private var resumeFromMs: Int?
    private let contentKey: String?
    private var progressTimer: Timer?

    /// Whether we've already retried with software decoding after a hw-decode failure.
    private var softwareDecodeRetryDone = false
    /// Watchdog: if audio plays but no video frame appears within ~6s, retry in software.
    private var videoWatchdog: Timer?

    // UI
    private let videoView = UIView()
    private let overlayView = UIView()
    private let titleLabel = UILabel()
    private let timeLabel = UILabel()
    private let progressBar = UIProgressView(progressViewStyle: .default)
    private var overlayTimer: Timer?
    private var isOverlayVisible = true

    init(url: URL, title: String, resumeFromMs: Int? = nil, contentKey: String? = nil) {
        self.url = url
        self.videoTitle = title
        self.resumeFromMs = resumeFromMs
        self.contentKey = contentKey
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupVideoView()
        setupOverlay()
        setupGestures()
        setupPlayer()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        mediaPlayer.play()

        // Resume from position
        if let ms = resumeFromMs, ms > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self, self.mediaPlayer.isPlaying else { return }
                self.mediaPlayer.time = VLCTime(int: Int32(ms))
            }
        }

        startOverlayAutoHide()
        startProgressTracking()
        startVideoWatchdog()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Progress has to be saved BEFORE stop() (time becomes 0 once stopped).
        // We read position here while the player is still decoding, and defer
        // the actual stop() to viewDidDisappear so it never blocks the main
        // thread during the dismiss animation.
        saveVLCProgress()
        progressTimer?.invalidate()
        videoWatchdog?.invalidate()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        mediaPlayer.drawable = nil
        mediaPlayer.stop()
    }

    // MARK: - Watch Progress

    private func startProgressTracking() {
        guard contentKey != nil else { return }
        progressTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.saveVLCProgress() }
        }
    }

    private func saveVLCProgress() {
        guard let contentKey, mediaPlayer.media != nil else { return }
        let posMs = Int(mediaPlayer.time.intValue)
        let durMs: Int
        if let remaining = mediaPlayer.remainingTime {
            durMs = posMs + Int(abs(remaining.intValue))
        } else {
            durMs = 0
        }
        guard durMs > 0, posMs > 0 else { return }
        PlayerPresenter.syncService?.saveProgress(contentKey: contentKey, positionMs: posMs, durationMs: durMs, title: videoTitle)
    }

    // MARK: - Setup

    private func setupVideoView() {
        videoView.frame = view.bounds
        videoView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        videoView.backgroundColor = .black
        view.addSubview(videoView)
    }

    private func setupOverlay() {
        overlayView.frame = view.bounds
        overlayView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlayView.backgroundColor = .clear
        view.addSubview(overlayView)

        // Top gradient — use a UIView wrapper since CALayer.autoresizingMask is unavailable on tvOS
        let topGradientView = GradientView(
            colors: [UIColor.black.withAlphaComponent(0.7), .clear],
            frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 150)
        )
        topGradientView.autoresizingMask = [.flexibleWidth]
        overlayView.addSubview(topGradientView)

        // Bottom gradient
        let bottomGradientView = GradientView(
            colors: [.clear, UIColor.black.withAlphaComponent(0.7)],
            frame: CGRect(x: 0, y: view.bounds.height - 100, width: view.bounds.width, height: 100)
        )
        bottomGradientView.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
        overlayView.addSubview(bottomGradientView)

        // Title
        titleLabel.text = videoTitle
        titleLabel.font = .systemFont(ofSize: 38, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        overlayView.addSubview(titleLabel)

        // Time
        timeLabel.font = .monospacedDigitSystemFont(ofSize: 24, weight: .medium)
        timeLabel.textColor = .white.withAlphaComponent(0.8)
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        overlayView.addSubview(timeLabel)

        // Progress
        progressBar.progressTintColor = UIColor(red: 0.106, green: 0.42, blue: 0.541, alpha: 1) // 0x1B6B8A
        progressBar.trackTintColor = .white.withAlphaComponent(0.3)
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        overlayView.addSubview(progressBar)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: overlayView.safeAreaLayoutGuide.topAnchor, constant: 30),
            titleLabel.leadingAnchor.constraint(equalTo: overlayView.leadingAnchor, constant: 60),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: overlayView.trailingAnchor, constant: -60),

            progressBar.bottomAnchor.constraint(equalTo: overlayView.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            progressBar.leadingAnchor.constraint(equalTo: overlayView.leadingAnchor, constant: 60),
            progressBar.trailingAnchor.constraint(equalTo: overlayView.trailingAnchor, constant: -60),
            progressBar.heightAnchor.constraint(equalToConstant: 4),

            timeLabel.bottomAnchor.constraint(equalTo: progressBar.topAnchor, constant: -12),
            timeLabel.leadingAnchor.constraint(equalTo: progressBar.leadingAnchor),
        ])

        // Update timer
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateProgress()
            }
        }
    }

    private func setupGestures() {
        // Siri Remote touchpad swipes (no effect with Free / Bose remotes,
        // but kept so Siri Remote users get the same feel as before).
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(seekBackward))
        swipeLeft.direction = .left
        view.addGestureRecognizer(swipeLeft)

        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(seekForward))
        swipeRight.direction = .right
        view.addGestureRecognizer(swipeRight)

        // Long press (any button) — options menu. Works on Free / Bose because
        // their OK/Select button generates a sustained press that trips the
        // long-press recognizer reliably.
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        longPress.minimumPressDuration = 1.0
        view.addGestureRecognizer(longPress)

        // NOTE: Play/Pause, Select, Menu and D-pad arrows are all handled
        // directly in pressesBegan below. UITapGestureRecognizer with
        // allowedPressTypes proved unreliable with third-party remotes (IR
        // Free / Bose): their Select press is sustained long enough that the
        // long-press recognizer cancels the tap. Likewise UIKeyCommand only
        // fires for external keyboards, never for IR remotes' D-pad.
    }

    private func setupPlayer() {
        mediaPlayer.media = buildMedia(softwareDecode: false)
        mediaPlayer.drawable = videoView
        mediaPlayer.delegate = self
    }

    /// Build a VLCMedia tuned for IPTV/timeshift MPEG-TS streams.
    /// - softwareDecode: if true, disables VideoToolbox (used as a fallback when
    ///   hardware decoding fails — typical for some 1080i50 H.264 High-profile
    ///   streams served by Xtream catch-up where VideoToolbox refuses the SPS/PPS).
    private func buildMedia(softwareDecode: Bool) -> VLCMedia {
        let media = VLCMedia(url: url)

        // Caching — HD catch-up over re-muxing Xtream servers is bursty.
        // Generous buffers drastically reduce "audio only / no video" glitches.
        media.addOption("--network-caching=5000")
        media.addOption("--live-caching=3000")
        media.addOption("--file-caching=3000")
        media.addOption("--sout-mux-caching=3000")

        // Decoding
        if softwareDecode {
            media.addOption("--avcodec-hw=none")
        } else {
            // Prefer VideoToolbox explicitly on tvOS (more predictable than "any",
            // which can pick an incompatible path for 1080i50 H.264 streams).
            media.addOption("--avcodec-hw=videotoolbox")
        }
        // Multi-threaded decoder (0 = auto = ncpu)
        media.addOption("--avcodec-threads=0")
        // Skip broken frames rather than stalling the pipeline
        media.addOption("--avcodec-skiploopfilter=4")

        // Deinterlace: most FR catch-up is 1080i50 — auto-enable yadif when needed
        media.addOption("--deinterlace=-1")            // -1 = auto
        media.addOption("--deinterlace-mode=yadif")

        // MPEG-TS robustness
        media.addOption("--ts-trust-pcr")
        media.addOption("--no-ts-cc-check")            // tolerate continuity counter gaps

        return media
    }

    /// Restart playback with hardware decoding disabled. Called when VLC reports
    /// an error OR when audio plays without any video frame after a few seconds.
    private func retryWithSoftwareDecode() {
        guard !softwareDecodeRetryDone else { return }
        softwareDecodeRetryDone = true

        let resumeMs = Int(mediaPlayer.time.intValue)
        mediaPlayer.stop()
        mediaPlayer.media = buildMedia(softwareDecode: true)
        mediaPlayer.play()
        if resumeMs > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self, self.mediaPlayer.isPlaying else { return }
                self.mediaPlayer.time = VLCTime(int: Int32(resumeMs))
            }
        }
        // brief hint to the user
        titleLabel.text = "Décodage logiciel…"
        showOverlay()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.titleLabel.text = self?.videoTitle
        }
    }

    /// If audio is decoding but no video frame has appeared after ~6s, the
    /// hardware decoder likely rejected the video elementary stream. Retry in
    /// software before giving up.
    private func startVideoWatchdog() {
        videoWatchdog?.invalidate()
        videoWatchdog = Timer.scheduledTimer(withTimeInterval: 6.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                guard !self.softwareDecodeRetryDone else { return }
                let size = self.mediaPlayer.videoSize
                let audible = (self.mediaPlayer.audioTrackIndexes as? [Int32])?.isEmpty == false
                if (size.width <= 0 || size.height <= 0) && audible {
                    self.retryWithSoftwareDecode()
                }
            }
        }
    }

    // MARK: - Button handling (UIPress — works for Siri Remote AND Free / Bose)
    //
    // tvOS routes physical remote button presses here as UIPress events with
    // their press.type set to one of the UIPress.PressType cases:
    //   .select / .menu / .playPause / .upArrow / .downArrow / .leftArrow /
    //   .rightArrow / .pageUp / .pageDown
    //
    // The Siri Remote generates the same events for clicks on the touchpad's
    // center / top / bottom / left / right zones, so a single pressesBegan
    // implementation covers both input types. External keyboards fall into the
    // `press.key` branch at the end.

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var handled = false
        for press in presses {
            switch press.type {
            case .menu:
                // Swallow on Began; the actual dismiss happens on Ended (HIG).
                return
            case .select:
                handleSelect()
                handled = true
            case .leftArrow:
                seekBackward()
                handled = true
            case .rightArrow:
                seekForward()
                handled = true
            case .playPause:
                handleTap()
                handled = true
            default:
                // External keyboard fallback (USB / Bluetooth keyboards).
                if let key = press.key {
                    switch key.keyCode {
                    case .keyboardLeftArrow: seekBackward(); handled = true
                    case .keyboardRightArrow: seekForward(); handled = true
                    case .keyboardReturnOrEnter, .keyboardSpacebar: handleSelect(); handled = true
                    default: break
                    }
                }
            }
        }
        if !handled { super.pressesBegan(presses, with: event) }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            if press.type == .menu {
                handleMenu()
                return
            }
        }
        super.pressesEnded(presses, with: event)
    }

    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            if press.type == .menu { return }
        }
        super.pressesCancelled(presses, with: event)
    }

    // MARK: - Gestures

    @objc private func handleTap() {
        if mediaPlayer.isPlaying {
            mediaPlayer.pause()
        } else {
            mediaPlayer.play()
        }
        showOverlay()
    }

    @objc private func handleSelect() {
        toggleOverlay()
    }

    @objc private func handleMenu() {
        // Stop is deferred to viewDidDisappear so it never blocks main thread
        // during the dismiss animation (see viewWillDisappear for details).
        dismiss(animated: true)
    }

    @objc private func seekForward() {
        mediaPlayer.jumpForward(30)
        showOverlay()
    }

    @objc private func seekBackward() {
        mediaPlayer.jumpBackward(15)
        showOverlay()
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        showOptionsMenu()
    }

    // MARK: - Options

    private func showOptionsMenu() {
        let alert = UIAlertController(
            title: "Options",
            message: "← → Reculer / Avancer · Play/Pause · Menu Retour",
            preferredStyle: .actionSheet
        )

        // Audio tracks
        let audioTracks = mediaPlayer.audioTrackNames as? [String] ?? []
        if audioTracks.count > 1 {
            alert.addAction(UIAlertAction(title: "🔊 Audio (\(audioTracks.count) pistes)", style: .default) { [weak self] _ in
                self?.showAudioPicker()
            })
        }

        // Subtitle tracks
        let subTracks = mediaPlayer.videoSubTitlesNames as? [String] ?? []
        if !subTracks.isEmpty {
            alert.addAction(UIAlertAction(title: "💬 Sous-titres (\(subTracks.count) pistes)", style: .default) { [weak self] _ in
                self?.showSubtitlePicker()
            })
        }

        // Aspect ratio
        alert.addAction(UIAlertAction(title: "📐 Format vidéo", style: .default) { [weak self] _ in
            self?.cycleAspectRatio()
        })

        // Sleep timer
        let timerTitle = SleepTimerManager.shared.isActive
            ? "⏰ Minuterie (\(SleepTimerManager.shared.remainingMinutes) min)"
            : "⏰ Minuterie de veille"
        alert.addAction(UIAlertAction(title: timerTitle, style: .default) { [weak self] _ in
            guard let self else { return }
            SleepTimerManager.showPicker(from: self)
        })

        alert.addAction(UIAlertAction(title: "Fermer", style: .cancel))
        present(alert, animated: true)
    }

    private func showAudioPicker() {
        let alert = UIAlertController(title: "Piste audio", message: nil, preferredStyle: .actionSheet)
        let names = mediaPlayer.audioTrackNames as? [String] ?? []
        let indexes = mediaPlayer.audioTrackIndexes as? [Int32] ?? []
        let current = mediaPlayer.currentAudioTrackIndex

        for (i, name) in names.enumerated() where i < indexes.count {
            let idx = indexes[i]
            let label = idx == current ? "✓ \(name)" : name
            alert.addAction(UIAlertAction(title: label, style: .default) { [weak self] _ in
                self?.mediaPlayer.currentAudioTrackIndex = idx
            })
        }
        alert.addAction(UIAlertAction(title: "Retour", style: .cancel))
        present(alert, animated: true)
    }

    private func showSubtitlePicker() {
        let alert = UIAlertController(title: "Sous-titres", message: nil, preferredStyle: .actionSheet)
        let names = mediaPlayer.videoSubTitlesNames as? [String] ?? []
        let indexes = mediaPlayer.videoSubTitlesIndexes as? [Int32] ?? []
        let current = mediaPlayer.currentVideoSubTitleIndex

        // Off option
        let isOff = current == -1
        alert.addAction(UIAlertAction(title: isOff ? "✓ Désactivés" : "Désactivés", style: .default) { [weak self] _ in
            self?.mediaPlayer.currentVideoSubTitleIndex = -1
        })

        for (i, name) in names.enumerated() where i < indexes.count {
            let idx = indexes[i]
            let label = idx == current ? "✓ \(name)" : name
            alert.addAction(UIAlertAction(title: label, style: .default) { [weak self] _ in
                self?.mediaPlayer.currentVideoSubTitleIndex = idx
            })
        }
        alert.addAction(UIAlertAction(title: "Retour", style: .cancel))
        present(alert, animated: true)
    }

    private var aspectRatioIndex = 0
    private let aspectRatios: [(label: String, value: String?)] = [
        ("Par défaut", nil),
        ("16:9", "16:9"),
        ("4:3", "4:3"),
        ("Remplir", "FILL"),
    ]

    private func cycleAspectRatio() {
        aspectRatioIndex = (aspectRatioIndex + 1) % aspectRatios.count
        let ratio = aspectRatios[aspectRatioIndex]
        if let value = ratio.value {
            mediaPlayer.videoAspectRatio = UnsafeMutablePointer<CChar>(mutating: (value as NSString).utf8String)
        } else {
            mediaPlayer.videoAspectRatio = nil
        }
        // Show brief overlay
        titleLabel.text = "Format : \(ratio.label)"
        showOverlay()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.titleLabel.text = self?.videoTitle
        }
    }

    // MARK: - Overlay

    private func toggleOverlay() {
        if isOverlayVisible {
            hideOverlay()
        } else {
            showOverlay()
        }
    }

    private func showOverlay() {
        overlayTimer?.invalidate()
        UIView.animate(withDuration: 0.3) { self.overlayView.alpha = 1 }
        isOverlayVisible = true
        startOverlayAutoHide()
    }

    private func hideOverlay() {
        UIView.animate(withDuration: 0.5) { self.overlayView.alpha = 0 }
        isOverlayVisible = false
    }

    private func startOverlayAutoHide() {
        overlayTimer?.invalidate()
        overlayTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.hideOverlay()
            }
        }
    }

    private func updateProgress() {
        guard mediaPlayer.media != nil else { return }
        let position = mediaPlayer.position
        progressBar.progress = position

        let current = mediaPlayer.time.stringValue ?? "--:--"
        let remaining = mediaPlayer.remainingTime?.stringValue ?? "--:--"
        timeLabel.text = "\(current)  /  \(remaining)"
    }
}

// MARK: - VLCMediaPlayerDelegate

extension VLCPlayerViewController: VLCMediaPlayerDelegate {
    nonisolated func mediaPlayerStateChanged(_ aNotification: Notification) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            switch mediaPlayer.state {
            case .error:
                // One automatic retry with software decoding before giving up.
                if !softwareDecodeRetryDone {
                    retryWithSoftwareDecode()
                    return
                }
                let alert = UIAlertController(
                    title: "Erreur de lecture",
                    message: "Impossible de lire ce contenu.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "Fermer", style: .default) { [weak self] _ in
                    self?.dismiss(animated: true)
                })
                present(alert, animated: true)
            case .ended:
                dismiss(animated: true)
            default:
                break
            }
        }
    }
}

// MARK: - Gradient View (CALayer.autoresizingMask unavailable on tvOS)

private final class GradientView: UIView {
    init(colors: [UIColor], frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        let gradient = CAGradientLayer()
        gradient.colors = colors.map(\.cgColor)
        gradient.frame = bounds
        layer.addSublayer(gradient)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        (layer.sublayers?.first as? CAGradientLayer)?.frame = bounds
    }
}
