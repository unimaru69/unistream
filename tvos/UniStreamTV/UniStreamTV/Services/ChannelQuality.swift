import Foundation

/// Reads the quality tag panels put in channel names ("TF1 FHD", "TF1 HD",
/// "FR| TF1 4K HEVC") and finds the other variants of the same channel.
///
/// Used to offer a lighter variant when a stream keeps stalling: on a line
/// that cannot carry the FHD feed, the HD one of the same channel plays.
enum ChannelQuality {
    enum Tier: Int, Comparable, CaseIterable {
        case sd = 1, hd, fhd, uhd

        static func < (lhs: Tier, rhs: Tier) -> Bool { lhs.rawValue < rhs.rawValue }

        var label: String {
            switch self {
            case .sd: return "SD"
            case .hd: return "HD"
            case .fhd: return "FHD"
            case .uhd: return "4K"
            }
        }
    }

    private static let tierWords: [String: Tier] = [
        "SD": .sd, "480P": .sd, "576P": .sd,
        "HD": .hd, "720P": .hd,
        "FHD": .fhd, "1080P": .fhd, "FULLHD": .fhd,
        "UHD": .uhd, "4K": .uhd, "2160P": .uhd,
    ]

    /// Codec and transport tags that differ between variants without being
    /// part of the channel's name.
    private static let noiseWords: Set<String> = ["HEVC", "H265", "H264", "AVC", "RAW", "BACKUP"]

    struct Parsed: Equatable {
        /// The name without quality and codec tags, upper-cased: the key
        /// that variants of one channel share.
        let base: String
        /// nil when the name carries no quality tag.
        let tier: Tier?
    }

    static func parse(_ name: String) -> Parsed {
        let words = name.uppercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
        var tier: Tier?
        var base: [String] = []
        for word in words {
            if let found = tierWords[word] {
                // "FULL HD" and the like: keep the highest tag seen.
                tier = max(tier ?? found, found)
            } else if !noiseWords.contains(word) {
                base.append(word)
            }
        }
        return Parsed(base: base.joined(separator: " "), tier: tier)
    }

    /// The other tagged variants of `channel` found in `all`, best first.
    /// One entry per tier — panels list the same variant in several
    /// categories.
    static func variants(of channel: Channel, in all: [Channel]) -> [(tier: Tier, channel: Channel)] {
        let own = parse(channel.name)
        guard !own.base.isEmpty else { return [] }
        var byTier: [Tier: Channel] = [:]
        for candidate in all where candidate.streamId != channel.streamId {
            let parsed = parse(candidate.name)
            guard parsed.base == own.base, let tier = parsed.tier, tier != own.tier else { continue }
            if byTier[tier] == nil { byTier[tier] = candidate }
        }
        return byTier.sorted { $0.key > $1.key }.map { (tier: $0.key, channel: $0.value) }
    }

    /// The next variant down from `channel`: HD for an FHD channel, SD for
    /// an HD one. nil when the channel has no quality tag or nothing lighter
    /// exists.
    static func lighterVariant(of channel: Channel, in all: [Channel]) -> (tier: Tier, channel: Channel)? {
        guard let own = parse(channel.name).tier else { return nil }
        return variants(of: channel, in: all).first { $0.tier < own }
    }
}

/// Remembers the channel watched before the current one, across player
/// sessions, so "previous channel" works after leaving and reopening the
/// player — the back-and-forth between two channels.
struct ChannelRecall: Equatable {
    private(set) var current: String?
    private(set) var previous: String?

    /// Call when a channel starts playing. Re-tuning the same channel
    /// (timeshift back to live, a reload) does not shift the history.
    mutating func watch(_ streamId: String) {
        guard streamId != current else { return }
        previous = current
        current = streamId
    }
}

/// Spots a live stream that keeps freezing, from the playback clock alone.
///
/// Fed once a second with the player's position. A freeze is the position
/// standing still while playback is supposed to run. VLC's own buffering
/// state is no use for this: it fires during normal playback too.
struct StallDetector: Equatable {
    /// Seconds after a (re)load during which nothing counts: opening a
    /// stream is not a stall.
    static let startupGrace: TimeInterval = 10
    /// Unchanged samples in a row that make one freeze.
    static let samplesPerFreeze = 2
    /// This many freezes within `window` means the line cannot carry it.
    static let freezesToReport = 3
    static let window: TimeInterval = 60

    private var startedAt: Date
    private var lastPosition: Int32?
    private var unchanged = 0
    private var freezes: [Date] = []
    private var reported = false

    init(now: Date = Date()) { startedAt = now }

    /// Returns true once, when the stream has frozen often enough to be
    /// worth offering a lighter variant. Stays quiet afterwards until
    /// `init` — one offer per channel load.
    mutating func sample(position: Int32, isPlaying: Bool, now: Date = Date()) -> Bool {
        guard !reported, now.timeIntervalSince(startedAt) >= Self.startupGrace else {
            lastPosition = position
            return false
        }
        defer { lastPosition = position }
        guard isPlaying, let last = lastPosition else {
            unchanged = 0
            return false
        }
        if position == last {
            unchanged += 1
            if unchanged == Self.samplesPerFreeze { freezes.append(now) }
        } else {
            unchanged = 0
        }
        freezes.removeAll { now.timeIntervalSince($0) > Self.window }
        if freezes.count >= Self.freezesToReport {
            reported = true
            return true
        }
        return false
    }
}
