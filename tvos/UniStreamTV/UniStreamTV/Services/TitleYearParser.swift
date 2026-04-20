import Foundation

/// Parses raw IPTV titles into a clean `(title, year)` pair for TMDB lookups.
///
/// Handles common IPTV prefixes and quality tokens:
///   "FR| Fire Country - 2025"       -> ("Fire Country", 2025)
///   "FR| Fire Country (2025)"       -> ("Fire Country", 2025)
///   "SD| Cold Wallet FHD - 2023"    -> ("Cold Wallet", 2023)
///   "FHD Fire Country"              -> ("Fire Country", nil)
///   "=FR= FRANCE =FR="              -> ("FRANCE", nil)  (best-effort)
///
/// Mirror of the Dart `TitleYearParser` in the Flutter codebase so the two
/// platforms yield the same cache keys when they share a server.
enum TitleYearParser {

    struct Result {
        let title: String
        let year: Int?
        let original: String
        var isUsable: Bool { !title.isEmpty }
    }

    static func parse(_ raw: String) -> Result {
        let original = raw
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return Result(title: "", year: nil, original: original) }

        // Drop country / quality prefix: "FR|", "SD|", "FHD|", "VO|" …
        if let match = s.range(
            of: #"^[A-Z]{2,4}[-\s]?\|\s*"#,
            options: [.regularExpression, .caseInsensitive]
        ) {
            s.removeSubrange(match)
        }

        // Extract trailing 4-digit year (wrapped in ()/[], separated by dash or space).
        var year: Int?
        if let yMatch = s.range(
            of: #"[\s\-\(\[]?(19|20)\d{2}[\)\]]?\s*$"#,
            options: .regularExpression
        ) {
            let yearSlice = s[yMatch]
            if let digits = yearSlice.range(of: #"(19|20)\d{2}"#, options: .regularExpression) {
                year = Int(yearSlice[digits])
            }
            s.removeSubrange(yMatch)
            s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Drop quality tokens wherever they sit.
        let qualityPattern =
            #"\b(FHD|HD|SD|4K|UHD|HEVC|HDR|H\.?264|H\.?265|X\.?264|X\.?265|"# +
            #"BluRay|BRRip|WEB[-.]?DL|WEBRip|HDTV|DVDRip|REMUX|MULTI|VOSTFR|VOST|VFF|VF|VO)\b"#
        s = s.replacingOccurrences(
            of: qualityPattern,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )

        // Drop separators + squeeze whitespace.
        s = s.replacingOccurrences(of: #"[\-\(\)\[\]\|]+"#, with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)

        return Result(title: s, year: year, original: original)
    }
}
