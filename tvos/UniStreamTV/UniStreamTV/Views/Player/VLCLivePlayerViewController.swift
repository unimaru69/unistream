import UIKit
import VLCKitSPM

/// VLC-based live TV player with channel zapping (up/down/left/right arrows).
/// Same gesture mapping as the AVPlayer zapping controller.
final class VLCLivePlayerViewController: UIViewController {

    private let mediaPlayer = VLCMediaPlayer()
    private var channels: [Channel]
    private var currentIndex: Int
    private let api: XtreamAPIService

    private let videoView = UIView()
    private let channelLabel = UILabel()
    private let channelNumberLabel = UILabel()
    private var hideOverlayTimer: Timer?

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
        setupGestures()
        loadCurrentChannel()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        mediaPlayer.play()
        showChannelOverlay()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        hideOverlayTimer?.invalidate()
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
        channelLabel.font = .systemFont(ofSize: 42, weight: .bold)
        channelLabel.textColor = .white
        channelLabel.textAlignment = .center
        channelLabel.alpha = 0
        channelLabel.layer.shadowColor = UIColor.black.cgColor
        channelLabel.layer.shadowOffset = CGSize(width: 0, height: 2)
        channelLabel.layer.shadowOpacity = 0.8
        channelLabel.layer.shadowRadius = 8
        channelLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(channelLabel)

        channelNumberLabel.font = .systemFont(ofSize: 24, weight: .medium)
        channelNumberLabel.textColor = .white.withAlphaComponent(0.7)
        channelNumberLabel.textAlignment = .center
        channelNumberLabel.alpha = 0
        channelNumberLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(channelNumberLabel)

        NSLayoutConstraint.activate([
            channelLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            channelLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            channelLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 60),
            channelLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -60),
            channelNumberLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            channelNumberLabel.topAnchor.constraint(equalTo: channelLabel.bottomAnchor, constant: 8),
        ])
    }

    private func setupGestures() {
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(zapNext))
        swipeLeft.direction = .left
        view.addGestureRecognizer(swipeLeft)

        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(zapPrev))
        swipeRight.direction = .right
        view.addGestureRecognizer(swipeRight)
    }

    // Arrow keys for non-Siri remotes (Free, Bbox, etc.)
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

    // MARK: - Zapping

    @objc private func zapNext() { zap(delta: 1) }
    @objc private func zapPrev() { zap(delta: -1) }

    private func zap(delta: Int) {
        guard !channels.isEmpty else { return }
        currentIndex = (currentIndex + delta + channels.count) % channels.count
        loadCurrentChannel()
        showChannelOverlay()
    }

    private func loadCurrentChannel() {
        let channel = channels[currentIndex]
        guard let url = api.liveStreamUrl(streamId: channel.streamId) else { return }
        let media = VLCMedia(url: url)
        // Low-latency live options. Software decoding ON to maximize compatibility
        // (HEVC in MPEG-TS, some 10-bit HDR streams are problematic with HW decode).
        media.addOptions([
            "network-caching": 1500,
            "live-caching": 1500,
        ])
        mediaPlayer.media = media
        mediaPlayer.play()
    }

    private func showChannelOverlay() {
        let channel = channels[currentIndex]
        channelLabel.text = channel.name
        channelNumberLabel.text = "\(currentIndex + 1) / \(channels.count)"
        UIView.animate(withDuration: 0.2) {
            self.channelLabel.alpha = 1
            self.channelNumberLabel.alpha = 1
        }
        hideOverlayTimer?.invalidate()
        hideOverlayTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { [weak self] _ in
            Task { @MainActor in
                UIView.animate(withDuration: 0.5) {
                    self?.channelLabel.alpha = 0
                    self?.channelNumberLabel.alpha = 0
                }
            }
        }
    }
}
