import Foundation

/// Playback preferences kept on the device: which audio and subtitle
/// language to select when a film, episode or channel starts.
///
/// Mirrors the Flutter app's "Langues" settings. Pure and VLC-free so the
/// matching rules can be tested; `VLCPreferredTracks` applies them.
enum PlaybackPreferences {
    static let audioLanguageKey = "player.pref.audioLanguage"
    static let subtitleLanguageKey = "player.pref.subtitleLanguage"

    /// Audio: leave the file's default track alone.
    static let original = ""
    /// Subtitles: turn them off, whatever the file marks as default.
    static let subtitlesOff = "off"

    struct Option: Identifiable, Hashable {
        let id: String
        let label: String
    }

    private static let languages: [Option] = [
        Option(id: "fr", label: "Français"),
        Option(id: "en", label: "English"),
        Option(id: "de", label: "Deutsch"),
        Option(id: "es", label: "Español"),
        Option(id: "it", label: "Italiano"),
    ]

    static let audioOptions: [Option] =
        [Option(id: original, label: "Piste d'origine")] + languages

    static let subtitleOptions: [Option] =
        [Option(id: original, label: "Selon le fichier"),
         Option(id: subtitlesOff, label: "Désactivés")] + languages

    static var audioLanguage: String {
        UserDefaults.standard.string(forKey: audioLanguageKey) ?? original
    }

    static var subtitleLanguage: String {
        UserDefaults.standard.string(forKey: subtitleLanguageKey) ?? original
    }

    // MARK: - Audio delay

    static let audioDelayKey = "player.pref.audioDelayMs"
    static let audioDelayStepMs = 50
    static let audioDelayLimitMs = 2000

    /// Lip-sync correction in milliseconds, kept across films and channels:
    /// the lag comes from the TV and sound bar, not from the content.
    /// Negative plays the sound earlier, positive later.
    static var audioDelayMs: Int {
        get { UserDefaults.standard.integer(forKey: audioDelayKey) }
        set {
            let clamped = min(max(newValue, -audioDelayLimitMs), audioDelayLimitMs)
            UserDefaults.standard.set(clamped, forKey: audioDelayKey)
        }
    }

    /// "0 ms", "+150 ms", "−100 ms".
    static func delayLabel(_ ms: Int) -> String {
        if ms == 0 { return "0 ms" }
        return (ms > 0 ? "+" : "−") + "\(abs(ms)) ms"
    }

    /// One audio or subtitle track as the player lists it.
    struct Track: Equatable {
        let id: Int32
        /// Display name, e.g. "Français - [Français]" or "Track 2 - [English]".
        let name: String
        /// Language tag from the container when there is one ("fre", "eng").
        let language: String?
    }

    /// Every spelling a file may use for a language: ISO 639-1 and 639-2
    /// codes, the name in English and French, and the usual release tags.
    private static let aliases: [String: Set<String>] = [
        "fr": ["fr", "fre", "fra", "french", "francais", "vf", "vff", "vfq", "vfi", "truefrench"],
        "en": ["en", "eng", "english", "anglais"],
        "de": ["de", "deu", "ger", "german", "deutsch", "allemand"],
        "es": ["es", "spa", "spanish", "espanol", "espagnol", "castellano"],
        "it": ["it", "ita", "italian", "italiano", "italien"],
    ]

    /// Whole-word match on the language tag and on the words of the name.
    /// Never a substring test: "en" must not match "French".
    static func matches(_ track: Track, language: String) -> Bool {
        guard let wanted = aliases[language] else { return false }
        let text = [track.language ?? "", track.name].joined(separator: " ")
        let words = text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .lowercased()
            .split(whereSeparator: { !$0.isLetter })
        return words.contains { wanted.contains(String($0)) }
    }

    /// The first track in `tracks` spoken or written in `language`, or nil
    /// when there is no preference or nothing matches. Entries with a
    /// negative id are the player's "Disable" rows, never a real track.
    static func preferredTrack(in tracks: [Track], language: String) -> Track? {
        guard !language.isEmpty, language != subtitlesOff else { return nil }
        return tracks.first { $0.id >= 0 && matches($0, language: language) }
    }
}
