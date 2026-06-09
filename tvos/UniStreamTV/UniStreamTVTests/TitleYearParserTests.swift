import XCTest
@testable import UniStreamTV

final class TitleYearParserTests: XCTestCase {

    private func assertParse(_ raw: String, _ title: String, _ year: Int?,
                             file: StaticString = #filePath, line: UInt = #line) {
        let r = TitleYearParser.parse(raw)
        XCTAssertEqual(r.title, title, "title for \"\(raw)\"", file: file, line: line)
        XCTAssertEqual(r.year, year, "year for \"\(raw)\"", file: file, line: line)
    }

    func testEmpty() {
        assertParse("", "", nil)
        assertParse("   ", "", nil)
    }

    // Legacy format (no leading pipe) must keep working.
    func testNonPipedPrefix() {
        assertParse("FR| Fire Country - 2025", "Fire Country", 2025)
        assertParse("SD| Cold Wallet FHD - 2023", "Cold Wallet", 2023)
        assertParse("FHD Fire Country", "Fire Country", nil)
    }

    // Regression: the new server wraps the tag in pipes ("|FR| ..."), which the
    // old parser left as "FR Title" and broke every TMDB lookup.
    func testLeadingPipeTag() {
        assertParse("|FR| Extravagances (1995)", "Extravagances", 1995)
        assertParse("|FR| Nuremberg (2025)", "Nuremberg", 2025)
        assertParse("|IT| Mortal Kombat II (2026)", "Mortal Kombat II", 2026)
    }

    func testPipeTagWithQuality() {
        assertParse("|FR-4K DV| Michael (2026)", "Michael", 2026)
        assertParse("|IT-4K| Mortal Kombat II (2026)", "Mortal Kombat II", 2026)
    }

    func testStackedPipeTags() {
        assertParse("|VO|STFR| Yowayowa Sensei (2026)", "Yowayowa Sensei", 2026)
    }

    func testTrailingJunkAfterDoublePipe() {
        assertParse("|FR| La casa de papel (2017) || MULTI", "La casa de papel", 2017)
    }

    func testYearNotAtEnd() {
        assertParse("|QC| Vie de chantier (2018) (VFQ)", "Vie de chantier", 2018)
    }

    func testPreservesIntraWordDashes() {
        assertParse("|FR| 9-1-1: Lone Star (2020)", "9-1-1: Lone Star", 2020)
    }
}
