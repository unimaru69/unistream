import XCTest
@testable import UniStreamTV

final class HeroCandidatesTests: XCTestCase {
    private func vod(_ id: String, _ name: String, category: String? = nil, rating: String? = "7",
                     icon: String? = "https://example.invalid/p.jpg", plot: String? = "Plot",
                     added: String? = nil) -> VodItem {
        var json: [String: Any] = ["stream_id": id, "name": name]
        json["category_name"] = category
        json["rating"] = rating
        json["stream_icon"] = icon
        json["plot"] = plot
        json["added"] = added
        return VodItem(json: json)
    }

    private func series(_ id: String, _ name: String, added: String? = nil) -> SeriesItem {
        var json: [String: Any] = ["series_id": id, "name": name, "rating": "8",
                                   "cover": "https://example.invalid/c.jpg", "plot": "Plot"]
        json["last_modified"] = added
        return SeriesItem(json: json)
    }

    func testProviderTagOnlyReadsAShortLeadingPrefix() {
        XCTAssertEqual(HeroCandidates.providerTag("FR| Le Film"), "FR")
        XCTAssertEqual(HeroCandidates.providerTag("ARTV|Titre"), "ARTV")
        XCTAssertEqual(HeroCandidates.providerTag(" fr |x"), "FR")
        XCTAssertEqual(HeroCandidates.providerTag("Un film | version longue"), "")
        // A short title with no bar is a title, not a language tag.
        XCTAssertEqual(HeroCandidates.providerTag("Ari"), "")
        XCTAssertEqual(HeroCandidates.providerTag(""), "")
    }

    func testDispreferredLanguagesNeverPickedEvenWithPerfectMetadata() {
        let picked = HeroCandidates.pick(
            vods: [vod("1", "AR| Film", rating: "10"), vod("2", "Film", category: "TR| Films", rating: "10"),
                   vod("3", "FR| Film", rating: "6")],
            series: [], primaryLang: "FR")
        XCTAssertEqual(picked.vods.map(\.id), ["vod_3"])
    }

    func testPreferredLanguageOutranksHigherRatingAndCategoryTagCounts() {
        let picked = HeroCandidates.pick(
            vods: [vod("1", "EN| Film", rating: "9"), vod("2", "FR| Film", rating: "6"),
                   vod("3", "Film", category: "FR| Cinéma", rating: "5")],
            series: [], primaryLang: "FR")
        XCTAssertEqual(picked.vods.map(\.id), ["vod_2", "vod_3", "vod_1"])
    }

    func testLowQualityTitlesDroppedAndListCapped() {
        let bare = vod("0", "Sans rien", rating: nil, icon: nil, plot: nil)
        let many = (1...40).map { vod("\($0)", "FR| Film \($0)") }
        let picked = HeroCandidates.pick(vods: [bare] + many, series: [series("9", "Série")], primaryLang: "FR")
        XCTAssertEqual(picked.vods.count, HeroCandidates.limit)
        XCTAssertFalse(picked.vods.contains { $0.id == "vod_0" })
        XCTAssertEqual(picked.series.map(\.id), ["series_9"])
    }

    func testNewestMixesFilmsAndSeriesByMostRecentTimestamp() {
        let newest = RecentlyAddedItem.newest(
            vods: [vod("1", "Ancien", added: "100"), vod("2", "Récent", added: "300"), vod("3", "Sans date")],
            series: [series("4", "Série", added: "200")], limit: 3)
        XCTAssertEqual(newest.map(\.id), ["vod_2", "series_4", "vod_1"])
    }
}
