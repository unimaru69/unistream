import UIKit
import VLCKitSPM

/// VLC-based live TV player with channel zapping and transport overlay.
final class VLCLivePlayerViewController: UIViewController {

    private let mediaPlayer = VLCMediaPlayer()
    private var channels: [Channel]
    private var currentIndex: Int
    private let api: XtreamAPIService

    // Views
    private let videoView = UIView()
    private let overlayView = UIView()
    private let channelNameLabel = UILabel()
    private let channelNumberLabel = UILabel()
    private let liveBadge = UILabel()
    private let clockLabel = UILabel()
    private let playPauseIcon = UIImageView()

    // Zap overlay (large, centered, auto-hiding)
    private let zapChannelLabel = UILabel()
    private let zapChannelNumber = UILabel()

    private var hideOverlayTimer: Timer?
    private var clockTimer: Timer?
    private var zapHideTimer: Timer?

    init(channels: [Channel], startIndex: Int, api: XtreamAPIService) {
        self.channels = channels
        self.currentIndex = max(0, min(startIndex, channels.count - 1))
        self.api = api
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupVideoView()
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
        // Swipe left/right — zap channel
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(zapNext))
        swipeLeft.direction = .left
        view.addGestureRecognizer(swipeLeft)

        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(zapPrev))
        swipeRight.direction = .right
        view.addGestureRecognizer(swipeRight)

        // Play/Pause — Siri Remote play/pause button
        let playPauseTap = UITapGestureRecognizer(target: self, action: #selector(togglePlayPause))
        playPauseTap.allowedPressTypes = [NSNumber(value: UIPress.PressType.playPause.rawValue)]
        view.addGestureRecognizer(playPauseTap)

        // Select (click center of touchpad) — toggle overlay
        let selectTap = UITapGestureRecognizer(target: self, action: #selector(toggleOverlay))
        selectTap.allowedPressTypes = [NSNumber(value: UIPress.PressType.select.rawValue)]
        view.addGestureRecognizer(selectTap)

        // Long press — options
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        longPress.minimumPressDuration = 1.0
        view.addGestureRecognizer(longPress)
    }

    // Arrow keys (third-party remotes) — up/down zap, left/right already via swipes.
    override var keyCommands: [UIKeyCommand]? {
        let up = UIKeyCommand(input: UIKeyCommand.inputUpArrow, modifierFlags: [], action: #selector(zapNext))
        let down = UIKeyCommand(input: UIKeyCommand.inputDownArrow, modifierFlags: [], action: #selector(zapPrev))
        let pageUp = UIKeyCommand(input: UIKeyCommand.inputPageUp, modifierFlags: [], action: #selector(zapNext))
        let pageDown = UIKeyCommand(input: UIKeyCommand.inputPageDown, modifierFlags: [], action: #selector(zapPrev))
        for c in [up, down, pageUp, pageDown] { c.wantsPriorityOverSystemBehavior = true }
        return [up, down, pageUp, pageDown]
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var handled = false
        for press in presses {
            guard let key = press.key else { continue }
            switch key.keyCode {
            case .keyboardUpArrow, .keyboardPageUp: zapNext(); handled = true
            case .keyboardDownArrow, .keyboardPageDown: zapPrev(); handled = true
            default: break
            }
        }
        if !handled { super.pressesBegan(presses, with: event) }
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
        let alert = UIAlertController(title: "Options", message: nil, preferredStyle: .actionSheet)

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
        let picker = UIAlertController(title: "Piste audio", message: nil, preferredStyle: .actionSheet)
        let names = mediaPlayer.audioTrackNames as? [String] ?? []
        let ids = mediaPlayer.audioTrackIndexes as? [NSNumber] ?? []
        for (name, id) in zip(names, ids) {
            let mark = (id.int32Value == mediaPlayer.currentAudioTrackIndex) ? "✓ " : ""
            picker.addAction(UIAlertAction(title: "\(mark)\(name)", style: .default) { [weak self] _ in
                self?.mediaPlayer.currentAudioTrackIndex = id.int32Value
            })
        }
        picker.addAction(UIAlertAction(title: "Retour", style: .cancel))
        present(picker, animated: true)
    }

    private func showSubtitlePicker() {
        let picker = UIAlertController(title: "Sous-titres", message: nil, preferredStyle: .actionSheet)
        let names = mediaPlayer.videoSubTitlesNames as? [String] ?? []
        let ids = mediaPlayer.videoSubTitlesIndexes as? [NSNumber] ?? []
        for (name, id) in zip(names, ids) {
            let mark = (id.int32Value == mediaPlayer.currentVideoSubTitleIndex) ? "✓ " : ""
            picker.addAction(UIAlertAction(title: "\(mark)\(name)", style: .default) { [weak self] _ in
                self?.mediaPlayer.currentVideoSubTitleIndex = id.int32Value
            })
        }
        picker.addAction(UIAlertAction(title: "Retour", style: .cancel))
        present(picker, animated: true)
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
        loadCurrentChannel()
        showZapOverlay()
        updateOverlayForCurrentChannel()
        showOverlay(autoHide: true)
    }

    private func loadCurrentChannel() {
        let channel = channels[currentIndex]
        guard let url = api.liveStreamUrl(streamId: channel.streamId) else { return }
        let media = VLCMedia(url: url)
        media.addOptions([
            "network-caching": 1500,
            "live-caching": 1500,
        ])
        mediaPlayer.media = media
        mediaPlayer.play()
        updateOverlayForCurrentChannel()
    }

    private func updateOverlayForCurrentChannel() {
        let channel = channels[currentIndex]
        channelNameLabel.text = channel.name
        channelNumberLabel.text = "Chaîne \(currentIndex + 1) / \(channels.count)"
    }

    // MARK: - Overlays

    private func showOverlay(autoHide: Bool) {
        UIView.animate(withDuration: 0.25) {
            self.overlayView.alpha = 1
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
    }
}
