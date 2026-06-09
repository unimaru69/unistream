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

        // Drop leading pipe-wrapped tag blocks: "|FR|", "|FR-4K DV|", "|IT-4K|",
        // and stacked ones like "|VO|STFR|". Some panels wrap the country/quality
        // tag in pipes (leading pipe first), e.g. "|FR| Extravagances (1995)".
        // Without this the "FR" leaks into the title and breaks TMDB matching.
        while let r = s.range(of: #"^\s*\|[^|]*\|\s*"#, options: .regularExpression) {
            s.removeSubrange(r)
        }

        // Drop a remaining country / quality prefix without a leading pipe:
        // "FR|", "SD|", "STFR|", "VO|", "BE|", "UK|", "US|" …
        if let match = s.range(
            of: #"^[A-Z]{2,4}[-\s]?\|\s*"#,
            options: [.regularExpression, .caseInsensitive]
        ) {
            s.removeSubrange(match)
        }

        // Cut trailing junk after a "||" separator, e.g.
        // "La casa de papel (2017) || MULTI".
        if let dbl = s.range(of: "||") {
            s = String(s[..<dbl.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Extract the year. Prefer a parenthesised/bracketed 4-digit year anywhere
        // ("(2017)", "[2020]") — robust against trailing tags like "(VFQ)" that
        // follow the year. Fall back to a bare trailing year (" - 2025", " 2025").
        var year: Int?
        if let paren = s.range(of: #"[\(\[](19|20)\d{2}[\)\]]"#, options: .regularExpression) {
            let slice = s[paren]
            if let digits = slice.range(of: #"(19|20)\d{2}"#, options: .regularExpression) {
                year = Int(slice[digits])
            }
            s = (String(s[..<paren.lowerBound]) + " " + String(s[paren.upperBound...]))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else if let tail = s.range(
            of: #"[\s\-\(\[]?(19|20)\d{2}[\)\]]?\s*$"#,
            options: .regularExpression
        ) {
            let slice = s[tail]
            if let digits = slice.range(of: #"(19|20)\d{2}"#, options: .regularExpression) {
                year = Int(slice[digits])
            }
            s.removeSubrange(tail)
            s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Drop common quality / version tokens wherever they sit.
        let qualityPattern =
            #"\b(FHD|HD|SD|4K|UHD|HEVC|HDR|H\.?264|H\.?265|X\.?264|X\.?265|"# +
            #"BluRay|BRRip|WEB[-.]?DL|WEBRip|HDTV|DVDRip|REMUX|MULTI|DV|"# +
            #"VOSTFR|VOST|STFR|VFQ|VFF|VF|VO)\b"#
        s = s.replacingOccurrences(
            of: qualityPattern,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )

        // Bracket / pipe separators → space (intra-word dashes like "9-1-1" kept).
        s = s.replacingOccurrences(of: #"[\(\)\[\]\|]+"#, with: " ", options: .regularExpression)
        // Per-token cleanup: strip edge dashes (drops standalone "-" and the
        // trailing dash left by "Title - 2025") while preserving intra-word dashes.
        s = s.split(separator: " ", omittingEmptySubsequences: true)
            .map { token in
                token.replacingOccurrences(
                    of: #"^[-–]+|[-–]+$"#, with: "", options: .regularExpression
                )
            }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)

        return Result(title: s, year: year, original: original)
    }
}
