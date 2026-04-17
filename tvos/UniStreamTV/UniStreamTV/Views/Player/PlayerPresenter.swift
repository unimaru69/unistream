import AVKit
import UIKit
import VLCKitSPM

/// Presents AVPlayerViewController via UIKit — the only reliable way on tvOS.
/// SwiftUI's fullScreenCover/NavigationLink break the focus engine.
@MainActor
enum PlayerPresenter {

    /// Shared sync service reference — set once from AppState at startup.
    static weak var syncService: SyncService?

    /// Whether to use VLC (true) or AVPlayer (false) for live streams.
    /// VLC supports HEVC in MPEG-TS, MPEG-1 audio, and many broadcast-style
    /// streams that AVPlayer refuses (audio-only / black screen).
    /// Toggle via Settings.
    static var useVlcForLive: Bool {
        get { UserDefaults.standard.object(forKey: "player.live.vlc") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "player.live.vlc") }
    }

    /// Present a live channel stream.
    static func playLive(url: URL, title: String? = nil, contentKey: String? = nil) {
        if useVlcForLive {
            let vlc = VLCPlayerViewController(url: url, title: title ?? "", resumeFromMs: nil, contentKey: contentKey)
            if let contentKey, let title { syncService?.registerPlayback(contentKey: contentKey, title: title) }
            guard let rootVC = rootViewController else { return }
            rootVC.present(vlc, animated: true)
            return
        }

        let player = AVPlayer(url: url)
        let playerVC = EnhancedPlayerViewController()
        playerVC.player = player
        playerVC.allowsPictureInPicturePlayback = false
        playerVC.requiresLinearPlayback = false
        if let contentKey { playerVC.progressTracker = ProgressTracker(player: player, contentKey: contentKey, title: title, syncService: syncService) }

        var metadata: [AVMetadataItem] = []
        if let title {
            let item = AVMutableMetadataItem()
            item.identifier = .commonIdentifierTitle
            item.value = title as NSString
            metadata.append(item)
        }
        if !metadata.isEmpty { player.currentItem?.externalMetadata = metadata }

        // Register in history immediately (title is stored even if playback is short)
        if let contentKey, let title { syncService?.registerPlayback(contentKey: contentKey, title: title) }

        guard let rootVC = rootViewController else { return }
        rootVC.present(playerVC, animated: true) {
            player.play()
            playerVC.progressTracker?.start()
        }
    }

    /// Present a live channel with zapping support (swipe left/right to change channel).
    static func playLiveWithZapping(
        channels: [Channel],
        startIndex: Int,
        api: XtreamAPIService
    ) {
        guard startIndex >= 0, startIndex < channels.count else { return }

        // VLC path — higher compatibility with HD/FHD HEVC streams.
        if useVlcForLive {
            let vlc = VLCLivePlayerViewController(channels: channels, startIndex: startIndex, api: api)
            guard let rootVC = rootViewController else { return }
            rootVC.present(vlc, animated: true)
            return
        }

        let channel = channels[startIndex]
        guard let url = api.liveStreamUrl(streamId: channel.streamId) else { return }

        let player = AVPlayer(url: url)
        let playerVC = ZappingPlayerViewController()
        playerVC.player = player
        playerVC.channels = channels
        playerVC.currentIndex = startIndex
        playerVC.api = api
        playerVC.updateMetadata(title: channel.name)

        // AVPlayerViewController natively supports subtitles & audio tracks
        // through its transport bar (swipe down on Siri Remote).
        playerVC.allowsPictureInPicturePlayback = false
        playerVC.requiresLinearPlayback = false

        guard let rootVC = rootViewController else { return }
        rootVC.present(playerVC, animated: true) {
            player.play()
        }
    }

    /// Present a VOD stream, optionally resuming from a position.
    /// Tries the given URL first. If playback fails, retries with alternate extensions.
    static func playVOD(url: URL, title: String? = nil, resumeFromMs: Int? = nil, contentKey: String? = nil) {
        let player = AVPlayer(url: url)
        if let ms = resumeFromMs, ms > 0 {
            let time = CMTime(seconds: Double(ms) / 1000.0, preferredTimescale: 600)
            player.seek(to: time)
        }

        let playerVC = EnhancedPlayerViewController()
        playerVC.player = player
        playerVC.allowsPictureInPicturePlayback = false
        playerVC.requiresLinearPlayback = false
        if let contentKey { playerVC.progressTracker = ProgressTracker(player: player, contentKey: contentKey, title: title, syncService: syncService) }

        // Metadata
        if let title {
            let titleMeta = AVMutableMetadataItem()
            titleMeta.identifier = .commonIdentifierTitle
            titleMeta.value = title as NSString
            player.currentItem?.externalMetadata = [titleMeta]
        }

        // Register in history immediately
        if let contentKey, let title { syncService?.registerPlayback(contentKey: contentKey, title: title) }

        guard let rootVC = rootViewController else { return }

        // Setup fallback handler for format compatibility
        let fallbackHandler = VODFallbackHandler(
            player: player,
            originalUrl: url,
            title: title,
            resumeFromMs: resumeFromMs,
            contentKey: contentKey,
            playerVC: playerVC
        )
        fallbackHandler.startObserving()

        // Keep handler alive via associated object
        objc_setAssociatedObject(playerVC, "fallbackHandler", fallbackHandler, .OBJC_ASSOCIATION_RETAIN)

        rootVC.present(playerVC, animated: true) {
            player.play()
            playerVC.progressTracker?.start()
        }
    }

    /// Present a catch-up/replay stream.
    /// Tries .ts → .m3u8 via AVPlayer, then falls back to VLC (which handles MPEG-TS
    /// that AVPlayer refuses, e.g. MPEG-1 audio, DVB teletext tracks, etc.).
    static func playCatchUp(url: URL, title: String) {
        let player = AVPlayer(url: url)

        let playerVC = EnhancedPlayerViewController()
        playerVC.player = player
        playerVC.allowsPictureInPicturePlayback = false
        playerVC.requiresLinearPlayback = false

        // Set metadata
        let titleItem = AVMutableMetadataItem()
        titleItem.identifier = .commonIdentifierTitle
        titleItem.value = title as NSString
        let descItem = AVMutableMetadataItem()
        descItem.identifier = .commonIdentifierDescription
        descItem.value = "Replay" as NSString
        player.currentItem?.externalMetadata = [titleItem, descItem]

        guard let rootVC = rootViewController else { return }

        // Build fallback chain: try .ts, then .m3u8; if both fail → VLC on original URL.
        let fallback = CatchUpFallbackHandler(
            player: player,
            originalUrl: url,
            title: title,
            playerVC: playerVC
        )
        fallback.startObserving()
        objc_setAssociatedObject(playerVC, "catchUpFallback", fallback, .OBJC_ASSOCIATION_RETAIN)

        rootVC.present(playerVC, animated: true) {
            player.play()
        }
    }

    /// Get the topmost presented view controller.
    private static var rootViewController: UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first,
              let root = scene.windows.first?.rootViewController
        else { return nil }

        var vc = root
        while let presented = vc.presentedViewController {
            vc = presented
        }
        return vc
    }
}

// MARK: - VOD Fallback Handler

/// Handles automatic format fallback for VOD streams.
///
/// Xtream API servers serve video at: /movie/user/pass/id.{ext}
/// AVPlayer supports: mp4, m4v, mov, ts, m3u8 (HLS).
/// AVPlayer does NOT support: mkv, avi, wmv, flv.
///
/// Strategy for unsupported formats (e.g. mkv):
/// 1. Try original ext (some MKV with h264+aac work in AVPlayer)
/// 2. Try .mp4 (some servers transcode on the fly)
/// 3. Try .m3u8 (HLS transcode — best compatibility)
/// 4. If all fail → show error and auto-dismiss
@MainActor
final class VODFallbackHandler: NSObject {
    private let player: AVPlayer
    private let originalUrl: URL
    private let title: String?
    private let resumeFromMs: Int?
    private let contentKey: String?
    private let fallbackUrls: [URL]
    private var currentIndex = 0
    private var observation: NSKeyValueObservation?
    private var failNotification: NSObjectProtocol?
    private weak var playerVC: UIViewController?

    init(player: AVPlayer, originalUrl: URL, title: String?, resumeFromMs: Int?, contentKey: String? = nil, playerVC: UIViewController? = nil) {
        self.player = player
        self.originalUrl = originalUrl
        self.title = title
        self.resumeFromMs = resumeFromMs
        self.contentKey = contentKey
        self.playerVC = playerVC
        self.fallbackUrls = Self.buildFallbackChain(from: originalUrl)
        super.init()
    }

    func startObserving() {
        observeCurrentItem()
    }

    private func observeCurrentItem() {
        observation?.invalidate()
        if let old = failNotification { NotificationCenter.default.removeObserver(old) }

        // KVO on status
        observation = player.currentItem?.observe(\.status, options: [.new]) { [weak self] item, _ in
            if item.status == .failed {
                Task { @MainActor [weak self] in
                    self?.tryNextFallback()
                }
            }
        }

        // Also observe playback failure notification
        failNotification = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tryNextFallback()
            }
        }
    }

    private func tryNextFallback() {
        guard currentIndex < fallbackUrls.count else {
            // All fallbacks exhausted — show error
            showFormatError()
            return
        }

        let nextUrl = fallbackUrls[currentIndex]
        currentIndex += 1

        let newItem = AVPlayerItem(url: nextUrl)
        if let title {
            let titleMeta = AVMutableMetadataItem()
            titleMeta.identifier = .commonIdentifierTitle
            titleMeta.value = title as NSString
            let descMeta = AVMutableMetadataItem()
            descMeta.identifier = .commonIdentifierDescription
            descMeta.value = "Tentative \(currentIndex + 1)…" as NSString
            newItem.externalMetadata = [titleMeta, descMeta]
        }

        player.replaceCurrentItem(with: newItem)
        if let ms = resumeFromMs, ms > 0 {
            let time = CMTime(seconds: Double(ms) / 1000.0, preferredTimescale: 600)
            player.seek(to: time)
        }
        player.play()

        observeCurrentItem()
    }

    private func showFormatError() {
        guard let vc = playerVC ?? Self.topViewController else { return }

        // AVPlayer can't play this format — hand off to VLC
        player.pause()
        cleanup()

        let vlcPlayer = VLCPlayerViewController(
            url: originalUrl,
            title: title ?? "",
            resumeFromMs: resumeFromMs,
            contentKey: contentKey
        )

        // Dismiss AVPlayerViewController, then present VLC player
        vc.dismiss(animated: true) {
            guard let rootVC = Self.topViewController else { return }
            rootVC.present(vlcPlayer, animated: true)
        }
    }

    private static var topViewController: UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first,
              let root = scene.windows.first?.rootViewController else { return nil }
        var vc = root
        while let presented = vc.presentedViewController { vc = presented }
        return vc
    }

    func cleanup() {
        observation?.invalidate()
        if let obs = failNotification { NotificationCenter.default.removeObserver(obs) }
    }

    /// Build the full fallback chain for a given URL.
    /// For mkv: try [original mkv, mp4, m3u8, ts]
    /// For mp4: try [m3u8, ts]
    /// For m3u8: try [mp4, ts]
    private static func buildFallbackChain(from url: URL) -> [URL] {
        let urlStr = url.absoluteString
        guard let dotRange = urlStr.range(of: ".", options: .backwards),
              dotRange.lowerBound > urlStr.startIndex else { return [] }

        let base = String(urlStr[urlStr.startIndex..<dotRange.lowerBound])
        let currentExt = String(urlStr[dotRange.upperBound...]).lowercased()

        let nativelySupported = Set(["mp4", "m4v", "mov", "m3u8", "ts"])

        // For natively supported: just try alternate supported formats
        if nativelySupported.contains(currentExt) {
            let alts = ["m3u8", "mp4", "ts"].filter { $0 != currentExt }
            return alts.compactMap { URL(string: "\(base).\($0)") }
        }

        // For unsupported (mkv, avi, etc.):
        // The original URL is already being played as the first attempt.
        // Some MKV files with h264+aac actually work in AVPlayer!
        // Then try mp4, m3u8, ts
        return ["mp4", "m3u8", "ts"].compactMap { URL(string: "\(base).\($0)") }
    }
}

// MARK: - Catch-up Fallback Handler

/// Tries .ts → .m3u8 via AVPlayer, then hands off to VLC if both fail.
@MainActor
final class CatchUpFallbackHandler: NSObject {
    private let player: AVPlayer
    private let originalUrl: URL
    private let title: String
    private weak var playerVC: UIViewController?

    private let fallbackUrls: [URL]
    private var currentIndex: Int = 0
    private var observation: NSKeyValueObservation?
    private var failNotification: NSObjectProtocol?
    private var handedOff = false

    init(player: AVPlayer, originalUrl: URL, title: String, playerVC: UIViewController?) {
        self.player = player
        self.originalUrl = originalUrl
        self.title = title
        self.playerVC = playerVC
        self.fallbackUrls = Self.buildFallbackChain(from: originalUrl)
    }

    func startObserving() {
        observeCurrentItem()
    }

    private func observeCurrentItem() {
        observation?.invalidate()
        if let old = failNotification { NotificationCenter.default.removeObserver(old) }

        observation = player.currentItem?.observe(\.status, options: [.new]) { [weak self] item, _ in
            if item.status == .failed {
                Task { @MainActor [weak self] in self?.tryNextFallback() }
            }
        }
        failNotification = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tryNextFallback() }
        }
    }

    private func tryNextFallback() {
        guard !handedOff else { return }
        guard currentIndex < fallbackUrls.count else {
            handOffToVLC()
            return
        }
        let nextUrl = fallbackUrls[currentIndex]
        currentIndex += 1

        let newItem = AVPlayerItem(url: nextUrl)
        let titleMeta = AVMutableMetadataItem()
        titleMeta.identifier = .commonIdentifierTitle
        titleMeta.value = title as NSString
        let descMeta = AVMutableMetadataItem()
        descMeta.identifier = .commonIdentifierDescription
        descMeta.value = "Replay (tentative \(currentIndex + 1)…)" as NSString
        newItem.externalMetadata = [titleMeta, descMeta]

        player.replaceCurrentItem(with: newItem)
        player.play()
        observeCurrentItem()
    }

    private func handOffToVLC() {
        guard !handedOff else { return }
        handedOff = true
        cleanup()
        player.pause()

        let vlcPlayer = VLCPlayerViewController(
            url: originalUrl,
            title: title,
            resumeFromMs: nil,
            contentKey: nil
        )

        guard let vc = playerVC ?? Self.topViewController else { return }
        vc.dismiss(animated: true) {
            guard let rootVC = Self.topViewController else { return }
            rootVC.present(vlcPlayer, animated: true)
        }
    }

    private func cleanup() {
        observation?.invalidate()
        observation = nil
        if let obs = failNotification { NotificationCenter.default.removeObserver(obs) }
        failNotification = nil
    }

    private static var topViewController: UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first,
              let root = scene.windows.first?.rootViewController else { return nil }
        var vc = root
        while let presented = vc.presentedViewController { vc = presented }
        return vc
    }

    /// For catch-up: if .ts → try .m3u8. If .m3u8 → try .ts. Else no alternate.
    private static func buildFallbackChain(from url: URL) -> [URL] {
        let urlStr = url.absoluteString
        guard let dotRange = urlStr.range(of: ".", options: .backwards),
              dotRange.lowerBound > urlStr.startIndex else { return [] }
        let base = String(urlStr[urlStr.startIndex..<dotRange.lowerBound])
        let ext = String(urlStr[dotRange.upperBound...]).lowercased()
        let alts: [String]
        switch ext {
        case "ts": alts = ["m3u8"]
        case "m3u8": alts = ["ts"]
        default: alts = ["m3u8", "ts"]
        }
        return alts.compactMap { URL(string: "\(base).\($0)") }
    }
}

// MARK: - Enhanced Player (sleep timer + aspect ratio via long press)

/// AVPlayerViewController with long-press menu for sleep timer & aspect ratio.
/// Subtitle/audio track selection is available natively via the transport bar
/// (swipe down on Siri Remote while video is playing).
final class EnhancedPlayerViewController: AVPlayerViewController, UIGestureRecognizerDelegate {

    /// Tracks watch progress and syncs to Supabase.
    var progressTracker: ProgressTracker?

    override func viewDidLoad() {
        super.viewDidLoad()
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        longPress.minimumPressDuration = 1.0
        longPress.delegate = self
        view.addGestureRecognizer(longPress)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        progressTracker?.saveNow()
        progressTracker?.stop()
    }

    // Allow our long press to coexist with native transport bar gestures
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        return true
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        // Load media selection groups asynchronously before showing menu
        Task { @MainActor in
            await showPlayerOptions()
        }
    }

    private func showPlayerOptions() async {
        guard let asset = player?.currentItem?.asset else {
            showBasicOptions()
            return
        }

        // Load media selection groups asynchronously (required for HLS)
        let audioGroup = try? await asset.loadMediaSelectionGroup(for: .audible)
        let subtitleGroup = try? await asset.loadMediaSelectionGroup(for: .legible)

        let alert = UIAlertController(
            title: "Options de lecture",
            message: nil,
            preferredStyle: .actionSheet
        )

        // Audio tracks
        if let audioGroup, audioGroup.options.count > 0 {
            let currentAudio = player?.currentItem?.currentMediaSelection.selectedMediaOption(in: audioGroup)
            let audioLabel = audioGroup.options.count > 1
                ? "🔊 Audio : \(currentAudio?.displayName ?? "Par défaut")"
                : "🔊 Audio : \(audioGroup.options.first?.displayName ?? "Par défaut")"
            alert.addAction(UIAlertAction(title: audioLabel, style: .default) { [weak self] _ in
                self?.showTrackPicker(group: audioGroup, title: "Piste audio", isSubtitle: false)
            })
        }

        // Subtitle tracks
        if let subtitleGroup, !subtitleGroup.options.isEmpty {
            let currentSub = player?.currentItem?.currentMediaSelection.selectedMediaOption(in: subtitleGroup)
            let subLabel = currentSub?.displayName ?? "Désactivés"
            alert.addAction(UIAlertAction(title: "💬 Sous-titres : \(subLabel)", style: .default) { [weak self] _ in
                self?.showTrackPicker(group: subtitleGroup, title: "Sous-titres", isSubtitle: true)
            })
        }

        // Aspect ratio
        alert.addAction(UIAlertAction(title: "📐 Format : \(aspectRatioLabel)", style: .default) { [weak self] _ in
            self?.cycleAspectRatio()
        })

        // Sleep timer
        let timerTitle = SleepTimerManager.shared.isActive
            ? "⏰ Minuterie (\(SleepTimerManager.shared.remainingMinutes) min restantes)"
            : "⏰ Minuterie de veille"
        alert.addAction(UIAlertAction(title: timerTitle, style: .default) { [weak self] _ in
            guard let self else { return }
            SleepTimerManager.showPicker(from: self)
        })

        alert.addAction(UIAlertAction(title: "Fermer", style: .cancel))
        present(alert, animated: true)
    }

    /// Fallback if asset is unavailable.
    private func showBasicOptions() {
        let alert = UIAlertController(title: "Options de lecture", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "📐 Format : \(aspectRatioLabel)", style: .default) { [weak self] _ in
            self?.cycleAspectRatio()
        })
        let timerTitle = SleepTimerManager.shared.isActive
            ? "⏰ Minuterie (\(SleepTimerManager.shared.remainingMinutes) min restantes)"
            : "⏰ Minuterie de veille"
        alert.addAction(UIAlertAction(title: timerTitle, style: .default) { [weak self] _ in
            guard let self else { return }
            SleepTimerManager.showPicker(from: self)
        })
        alert.addAction(UIAlertAction(title: "Fermer", style: .cancel))
        present(alert, animated: true)
    }

    // MARK: - Track Selection

    private func showTrackPicker(group: AVMediaSelectionGroup, title: String, isSubtitle: Bool) {
        let picker = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        let currentOption = player?.currentItem?.currentMediaSelection.selectedMediaOption(in: group)

        // "Off" option for subtitles
        if isSubtitle {
            let isOff = currentOption == nil
            picker.addAction(UIAlertAction(
                title: isOff ? "✓ Désactivés" : "Désactivés",
                style: .default
            ) { [weak self] _ in
                self?.player?.currentItem?.select(nil, in: group)
            })
        }

        for option in group.options {
            let isCurrent = option == currentOption
            let label = isCurrent ? "✓ \(option.displayName)" : option.displayName
            picker.addAction(UIAlertAction(title: label, style: .default) { [weak self] _ in
                self?.player?.currentItem?.select(option, in: group)
            })
        }

        picker.addAction(UIAlertAction(title: "Retour", style: .cancel))
        present(picker, animated: true)
    }
}

// MARK: - Zapping Player (swipe left/right to change channel)

/// Custom AVPlayerViewController that handles swipe left/right for channel zapping.
/// Uses left/right swipes instead of up/down to avoid conflicting with the native
/// transport bar (swipe down = subtitles/audio, swipe up = info panel).
final class ZappingPlayerViewController: AVPlayerViewController, UIGestureRecognizerDelegate {

    var channels: [Channel] = []
    var currentIndex: Int = 0
    var api: XtreamAPIService?

    /// Overlay label for channel name on zap.
    private lazy var channelOverlay: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 42, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.alpha = 0
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOffset = CGSize(width: 0, height: 2)
        label.layer.shadowOpacity = 0.8
        label.layer.shadowRadius = 8
        return label
    }()

    private lazy var channelNumberOverlay: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 24, weight: .medium)
        label.textColor = .white.withAlphaComponent(0.7)
        label.textAlignment = .center
        label.alpha = 0
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOffset = CGSize(width: 0, height: 2)
        label.layer.shadowOpacity = 0.8
        label.layer.shadowRadius = 4
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Swipe LEFT = next channel (channel +)
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeLeft))
        swipeLeft.direction = .left
        swipeLeft.delegate = self
        view.addGestureRecognizer(swipeLeft)

        // Swipe RIGHT = previous channel (channel -)
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeRight))
        swipeRight.direction = .right
        swipeRight.delegate = self
        view.addGestureRecognizer(swipeRight)

        // Long press = options menu (sleep timer, aspect ratio)
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        longPress.minimumPressDuration = 1.0
        longPress.delegate = self
        view.addGestureRecognizer(longPress)

        // Setup overlays
        view.addSubview(channelOverlay)
        view.addSubview(channelNumberOverlay)
        channelOverlay.translatesAutoresizingMaskIntoConstraints = false
        channelNumberOverlay.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            channelOverlay.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            channelOverlay.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            channelOverlay.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 100),
            channelOverlay.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -100),
            channelNumberOverlay.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            channelNumberOverlay.topAnchor.constraint(equalTo: channelOverlay.bottomAnchor, constant: 8),
        ])
    }

    // Allow our gestures to coexist with the system transport bar gestures
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        return true
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        Task { @MainActor in
            await showPlayerOptions()
        }
    }

    private func showPlayerOptions() async {
        let asset = player?.currentItem?.asset

        // Load media selection groups asynchronously (required for HLS)
        let audioGroup = try? await asset?.loadMediaSelectionGroup(for: .audible)
        let subtitleGroup = try? await asset?.loadMediaSelectionGroup(for: .legible)

        let alert = UIAlertController(
            title: "Options de lecture",
            message: "↑↓ ou ← → Changer de chaîne",
            preferredStyle: .actionSheet
        )

        // Audio tracks
        if let audioGroup, !audioGroup.options.isEmpty {
            let current = player?.currentItem?.currentMediaSelection.selectedMediaOption(in: audioGroup)
            let audioLabel = audioGroup.options.count > 1
                ? "🔊 Audio : \(current?.displayName ?? "Par défaut")"
                : "🔊 Audio : \(audioGroup.options.first?.displayName ?? "Par défaut")"
            alert.addAction(UIAlertAction(title: audioLabel, style: .default) { [weak self] _ in
                self?.showZappingTrackPicker(group: audioGroup, title: "Piste audio", isSubtitle: false)
            })
        }

        // Subtitle tracks
        if let subtitleGroup, !subtitleGroup.options.isEmpty {
            let current = player?.currentItem?.currentMediaSelection.selectedMediaOption(in: subtitleGroup)
            alert.addAction(UIAlertAction(title: "💬 Sous-titres : \(current?.displayName ?? "Désactivés")", style: .default) { [weak self] _ in
                self?.showZappingTrackPicker(group: subtitleGroup, title: "Sous-titres", isSubtitle: true)
            })
        }

        // Aspect ratio
        alert.addAction(UIAlertAction(title: "📐 Format : \(aspectRatioLabel)", style: .default) { [weak self] _ in
            self?.cycleAspectRatio()
        })

        // Sleep timer
        let timerTitle = SleepTimerManager.shared.isActive
            ? "⏰ Minuterie (\(SleepTimerManager.shared.remainingMinutes) min restantes)"
            : "⏰ Minuterie de veille"
        alert.addAction(UIAlertAction(title: timerTitle, style: .default) { [weak self] _ in
            guard let self else { return }
            SleepTimerManager.showPicker(from: self)
        })

        alert.addAction(UIAlertAction(title: "Fermer", style: .cancel))
        present(alert, animated: true)
    }

    private func showZappingTrackPicker(group: AVMediaSelectionGroup, title: String, isSubtitle: Bool) {
        let picker = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        let currentOption = player?.currentItem?.currentMediaSelection.selectedMediaOption(in: group)

        if isSubtitle {
            let isOff = currentOption == nil
            picker.addAction(UIAlertAction(
                title: isOff ? "✓ Désactivés" : "Désactivés",
                style: .default
            ) { [weak self] _ in
                self?.player?.currentItem?.select(nil, in: group)
            })
        }

        for option in group.options {
            let isCurrent = option == currentOption
            let label = isCurrent ? "✓ \(option.displayName)" : option.displayName
            picker.addAction(UIAlertAction(title: label, style: .default) { [weak self] _ in
                self?.player?.currentItem?.select(option, in: group)
            })
        }

        picker.addAction(UIAlertAction(title: "Retour", style: .cancel))
        present(picker, animated: true)
    }

    @objc private func handleSwipeLeft() {
        zapChannel(delta: 1)
    }

    @objc private func handleSwipeRight() {
        zapChannel(delta: -1)
    }

    // MARK: - Key-press zapping (for non-Siri remotes like Free TV remote)
    //
    // Siri Remote sends swipes → handled by UISwipeGestureRecognizer above.
    // Third-party remotes (Free, Bbox, etc.) send directional arrow HID keyboard
    // events. On tvOS the focus engine consumes up/down arrows before they reach
    // pressesBegan (to move focus onto the transport bar's audio/subtitle buttons).
    // UIKeyCommand is dispatched earlier in the responder chain and bypasses the
    // focus engine, so we use it to intercept arrow keys reliably.
    override var keyCommands: [UIKeyCommand]? {
        let up = UIKeyCommand(input: UIKeyCommand.inputUpArrow, modifierFlags: [], action: #selector(keyZapUp))
        let down = UIKeyCommand(input: UIKeyCommand.inputDownArrow, modifierFlags: [], action: #selector(keyZapDown))
        let pageUp = UIKeyCommand(input: UIKeyCommand.inputPageUp, modifierFlags: [], action: #selector(keyZapUp))
        let pageDown = UIKeyCommand(input: UIKeyCommand.inputPageDown, modifierFlags: [], action: #selector(keyZapDown))
        for cmd in [up, down, pageUp, pageDown] {
            cmd.wantsPriorityOverSystemBehavior = true
        }
        return [up, down, pageUp, pageDown]
    }

    @objc private func keyZapUp() { zapChannel(delta: 1) }
    @objc private func keyZapDown() { zapChannel(delta: -1) }

    // Fallback: some remotes / firmwares route directional presses as UIPress
    // rather than keyboard events; keep pressesBegan as a safety net.
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var handled = false
        for press in presses {
            guard let key = press.key else { continue }
            switch key.keyCode {
            case .keyboardUpArrow, .keyboardPageUp:
                zapChannel(delta: 1)
                handled = true
            case .keyboardDownArrow, .keyboardPageDown:
                zapChannel(delta: -1)
                handled = true
            default:
                break
            }
        }
        if !handled {
            super.pressesBegan(presses, with: event)
        }
    }

    @MainActor
    private func zapChannel(delta: Int) {
        guard !channels.isEmpty else { return }
        let newIndex = (currentIndex + delta + channels.count) % channels.count
        let channel = channels[newIndex]

        guard let api,
              let url = api.liveStreamUrl(streamId: channel.streamId)
        else { return }

        currentIndex = newIndex
        let newItem = AVPlayerItem(url: url)
        player?.replaceCurrentItem(with: newItem)
        updateMetadata(title: channel.name)
        player?.play()

        // Show channel overlay
        showChannelOverlay(name: channel.name, number: "\(newIndex + 1) / \(channels.count)")
    }

    private func showChannelOverlay(name: String, number: String) {
        channelOverlay.text = name
        channelNumberOverlay.text = number

        UIView.animate(withDuration: 0.2) {
            self.channelOverlay.alpha = 1
            self.channelNumberOverlay.alpha = 1
        }

        // Auto-hide after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            UIView.animate(withDuration: 0.5) {
                self?.channelOverlay.alpha = 0
                self?.channelNumberOverlay.alpha = 0
            }
        }
    }

    func updateMetadata(title: String) {
        let item = AVMutableMetadataItem()
        item.identifier = .commonIdentifierTitle
        item.value = title as NSString

        let desc = AVMutableMetadataItem()
        desc.identifier = .commonIdentifierDescription
        desc.value = "Chaîne \(currentIndex + 1)/\(channels.count) — ↑↓ ou ← → pour changer" as NSString

        player?.currentItem?.externalMetadata = [item, desc]
    }
}

// MARK: - Sleep Timer Support

/// Manages a sleep timer that auto-dismisses the player after a delay.
@MainActor
final class SleepTimerManager {
    static let shared = SleepTimerManager()

    private var sleepTask: Task<Void, Never>?
    private(set) var remainingMinutes: Int = 0
    private(set) var isActive: Bool = false

    /// Available timer presets in minutes.
    static let presets: [(label: String, minutes: Int)] = [
        ("15 min", 15),
        ("30 min", 30),
        ("45 min", 45),
        ("1 heure", 60),
        ("1h30", 90),
        ("2 heures", 120),
    ]

    func start(minutes: Int, playerVC: UIViewController) {
        cancel()
        remainingMinutes = minutes
        isActive = true

        sleepTask = Task { [weak playerVC] in
            // Countdown per minute
            for remaining in stride(from: minutes, through: 1, by: -1) {
                self.remainingMinutes = remaining
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled else { return }
            }
            // Time's up — pause and dismiss
            self.isActive = false
            self.remainingMinutes = 0
            guard let vc = playerVC else { return }
            if let playerVC = vc as? AVPlayerViewController {
                playerVC.player?.pause()
            }
            vc.dismiss(animated: true)
        }
    }

    func cancel() {
        sleepTask?.cancel()
        sleepTask = nil
        isActive = false
        remainingMinutes = 0
    }

    /// Shows a UIAlertController for picking sleep timer duration.
    static func showPicker(from viewController: UIViewController) {
        let alert = UIAlertController(
            title: "Minuterie de veille",
            message: shared.isActive
                ? "Minuterie active : \(shared.remainingMinutes) min restantes"
                : "Éteindre la lecture après…",
            preferredStyle: .actionSheet
        )

        for preset in presets {
            alert.addAction(UIAlertAction(title: preset.label, style: .default) { _ in
                shared.start(minutes: preset.minutes, playerVC: viewController)
            })
        }

        if shared.isActive {
            alert.addAction(UIAlertAction(title: "Annuler la minuterie", style: .destructive) { _ in
                shared.cancel()
            })
        }

        alert.addAction(UIAlertAction(title: "Fermer", style: .cancel))
        viewController.present(alert, animated: true)
    }
}

// MARK: - Aspect Ratio Support

extension AVPlayerViewController {
    /// Cycles through video gravity modes: fit → fill → resize aspect.
    func cycleAspectRatio() {
        switch videoGravity {
        case .resizeAspect:
            videoGravity = .resizeAspectFill
        case .resizeAspectFill:
            videoGravity = .resize
        default:
            videoGravity = .resizeAspect
        }
    }

    /// Returns the current aspect ratio label.
    var aspectRatioLabel: String {
        switch videoGravity {
        case .resizeAspect: return "Adapter"
        case .resizeAspectFill: return "Remplir"
        case .resize: return "Étirer"
        default: return "Adapter"
        }
    }
}

// MARK: - Progress Tracker (AVPlayer)

/// Periodically saves watch progress for AVPlayer-based playback.
@MainActor
final class ProgressTracker {
    private weak var player: AVPlayer?
    private let contentKey: String
    private let title: String?
    private weak var syncService: SyncService?
    private var timer: Timer?

    init(player: AVPlayer, contentKey: String, title: String? = nil, syncService: SyncService?) {
        self.player = player
        self.contentKey = contentKey
        self.title = title
        self.syncService = syncService
    }

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.saveNow() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func saveNow() {
        guard let player, let item = player.currentItem else { return }
        let posSec = CMTimeGetSeconds(player.currentTime())
        let durSec = CMTimeGetSeconds(item.duration)
        // Guard against NaN (indefinite duration, not yet loaded, etc.)
        guard posSec.isFinite, durSec.isFinite else { return }
        let posMs = Int(posSec * 1000)
        let durMs = Int(durSec * 1000)
        guard durMs > 0, posMs > 0 else { return }
        syncService?.saveProgress(contentKey: contentKey, positionMs: posMs, durationMs: durMs, title: title)
    }
}
