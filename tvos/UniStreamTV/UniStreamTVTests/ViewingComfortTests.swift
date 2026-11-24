import XCTest
@testable import UniStreamTV

final class ViewingComfortTests: XCTestCase {
    private func channel(_ id: String, _ name: String) -> Channel {
        Channel(json: ["stream_id": id, "name": name])
    }

    // MARK: - Quality variants

    func testParseSeparatesTheQualityTagFromTheChannelName() {
        XCTAssertEqual(ChannelQuality.parse("TF1 FHD"), .init(base: "TF1", tier: .fhd))
        XCTAssertEqual(ChannelQuality.parse("FR| TF1 HD"), .init(base: "FR TF1", tier: .hd))
        XCTAssertEqual(ChannelQuality.parse("Canal+ Sport 4K HEVC"), .init(base: "CANAL SPORT", tier: .uhd))
        XCTAssertEqual(ChannelQuality.parse("France 2"), .init(base: "FRANCE 2", tier: nil))
        // "HD" inside a word is part of the name, not a tag.
        XCTAssertEqual(ChannelQuality.parse("HDNet Movies"), .init(base: "HDNET MOVIES", tier: nil))
    }

    func testLighterVariantIsTheNextTierDownOfTheSameChannel() {
        let fhd = channel("1", "FR| TF1 FHD")
        let all = [fhd, channel("2", "FR| TF1 HD"), channel("3", "FR| TF1 SD"),
                   channel("4", "FR| TF1 4K"), channel("5", "FR| TF1 Séries Films HD")]
        XCTAssertEqual(ChannelQuality.lighterVariant(of: fhd, in: all)?.channel.streamId, "2")
        XCTAssertEqual(ChannelQuality.lighterVariant(of: all[1], in: all)?.channel.streamId, "3")
        XCTAssertNil(ChannelQuality.lighterVariant(of: all[2], in: all), "SD has nothing below it")
        XCTAssertEqual(ChannelQuality.variants(of: fhd, in: all).map(\.tier), [.uhd, .hd, .sd])
    }

    func testNoOfferForUntaggedChannelsOrWithoutSiblings() {
        let plain = channel("1", "France 2")
        XCTAssertNil(ChannelQuality.lighterVariant(of: plain, in: [plain, channel("2", "France 2 HD")]))
        let alone = channel("3", "Arte FHD")
        XCTAssertNil(ChannelQuality.lighterVariant(of: alone, in: [alone, channel("4", "Arte Concert HD")]))
    }

    func testDuplicateListingsOfAVariantCountOnce() {
        let fhd = channel("1", "M6 FHD")
        let all = [fhd, channel("2", "M6 HD"), channel("3", "M6 HD")]
        XCTAssertEqual(ChannelQuality.variants(of: fhd, in: all).map(\.channel.streamId), ["2"])
    }

    // MARK: - Previous channel

    func testRecallKeepsTheChannelBeforeTheCurrentOne() {
        var recall = ChannelRecall()
        recall.watch("a")
        XCTAssertNil(recall.previous)
        recall.watch("b")
        XCTAssertEqual(recall.previous, "a")
        recall.watch("b") // reload, or back from timeshift
        XCTAssertEqual(recall.previous, "a")
        recall.watch("a")
        XCTAssertEqual(recall.previous, "b", "Flipping between two channels keeps working")
    }

    // MARK: - Stall detection

    /// Feeds one sample a second; `frozen` seconds repeat the position.
    private func run(_ detector: inout StallDetector, from start: Date, seconds: [Bool],
                     playing: Bool = true) -> Bool {
        var position: Int32 = 0
        var reported = false
        for (offset, frozen) in seconds.enumerated() {
            if !frozen { position += 1000 }
            if detector.sample(position: position, isPlaying: playing,
                               now: start.addingTimeInterval(Double(offset))) {
                reported = true
            }
        }
        return reported
    }

    func testSteadyPlaybackNeverReports() {
        let start = Date()
        var detector = StallDetector(now: start)
        XCTAssertFalse(run(&detector, from: start, seconds: Array(repeating: false, count: 180)))
    }

    func testThreeFreezesInAMinuteReportOnce() {
        let start = Date()
        var detector = StallDetector(now: start)
        let playing = Array(repeating: false, count: 12)
        let freeze = [true, true, true]
        let pattern = playing + freeze + playing + freeze + playing + freeze + playing
        XCTAssertTrue(run(&detector, from: start, seconds: pattern))
        // One offer per channel load: more freezes stay quiet.
        XCTAssertFalse(run(&detector, from: start.addingTimeInterval(200), seconds: freeze + playing + freeze))
    }

    func testOpeningTheStreamAndPausingAreNotStalls() {
        let start = Date()
        var opening = StallDetector(now: start)
        XCTAssertFalse(run(&opening, from: start, seconds: Array(repeating: true, count: 9)))

        var paused = StallDetector(now: start)
        XCTAssertFalse(run(&paused, from: start, seconds: Array(repeating: true, count: 120), playing: false))
    }

    func testSpreadOutFreezesDoNotReport() {
        let start = Date()
        var detector = StallDetector(now: start)
        let calm = Array(repeating: false, count: 70)
        let pattern = calm + [true, true, true] + calm + [true, true, true] + calm + [true, true, true] + calm
        XCTAssertFalse(run(&detector, from: start, seconds: pattern))
    }

    // MARK: - Delay label

    func testDelayLabelSignsTheValue() {
        XCTAssertEqual(PlaybackPreferences.delayLabel(0), "0 ms")
        XCTAssertEqual(PlaybackPreferences.delayLabel(150), "+150 ms")
        XCTAssertEqual(PlaybackPreferences.delayLabel(-100), "−100 ms")
    }
}
