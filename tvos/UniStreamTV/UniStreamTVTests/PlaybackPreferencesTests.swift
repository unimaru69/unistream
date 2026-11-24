import XCTest
@testable import UniStreamTV

final class PlaybackPreferencesTests: XCTestCase {
    private typealias Track = PlaybackPreferences.Track

    func testMatchesLanguageTagAndEveryUsualSpelling() {
        XCTAssertTrue(PlaybackPreferences.matches(Track(id: 1, name: "Track 1", language: "fre"), language: "fr"))
        XCTAssertTrue(PlaybackPreferences.matches(Track(id: 1, name: "Track 1", language: "FRA"), language: "fr"))
        XCTAssertTrue(PlaybackPreferences.matches(Track(id: 1, name: "Français - [Français]", language: nil), language: "fr"))
        XCTAssertTrue(PlaybackPreferences.matches(Track(id: 1, name: "VFF DTS-HD MA 5.1", language: nil), language: "fr"))
        XCTAssertTrue(PlaybackPreferences.matches(Track(id: 2, name: "Track 2 - [English]", language: nil), language: "en"))
        XCTAssertTrue(PlaybackPreferences.matches(Track(id: 3, name: "Audio", language: "ger"), language: "de"))
    }

    /// The Flutter matcher is a substring test, so "en" matched "French".
    /// This one compares whole words.
    func testShortCodeNeverMatchesInsideAnotherWord() {
        XCTAssertFalse(PlaybackPreferences.matches(Track(id: 1, name: "French", language: nil), language: "en"))
        XCTAssertFalse(PlaybackPreferences.matches(Track(id: 1, name: "Deutsch", language: "deu"), language: "es"))
        XCTAssertFalse(PlaybackPreferences.matches(Track(id: 1, name: "Titre", language: nil), language: "it"))
    }

    func testPreferredTrackPicksTheFirstMatchAndSkipsTheDisableRow() {
        let tracks = [
            Track(id: -1, name: "Disable", language: nil),
            Track(id: 1, name: "English VO 7.1 Dolby TrueHD Atmos", language: "eng"),
            Track(id: 2, name: "French 5.1 DTS-HD MA", language: "fre"),
            Track(id: 3, name: "French commentary", language: "fre"),
        ]
        XCTAssertEqual(PlaybackPreferences.preferredTrack(in: tracks, language: "fr")?.id, 2)
        XCTAssertEqual(PlaybackPreferences.preferredTrack(in: tracks, language: "en")?.id, 1)
    }

    func testNoPreferenceOrNoMatchLeavesTheFileDefault() {
        let tracks = [Track(id: 1, name: "English", language: "eng")]
        XCTAssertNil(PlaybackPreferences.preferredTrack(in: tracks, language: PlaybackPreferences.original))
        XCTAssertNil(PlaybackPreferences.preferredTrack(in: tracks, language: PlaybackPreferences.subtitlesOff))
        XCTAssertNil(PlaybackPreferences.preferredTrack(in: tracks, language: "fr"))
        XCTAssertNil(PlaybackPreferences.preferredTrack(in: tracks, language: "xx"))
    }

    func testRateLabelUsesFrenchDecimalsWithoutTrailingZeros() {
        XCTAssertEqual(VLCPlayerViewController.rateLabel(1), "1×")
        XCTAssertEqual(VLCPlayerViewController.rateLabel(1.25), "1,25×")
        XCTAssertEqual(VLCPlayerViewController.rateLabel(0.5), "0,5×")
    }
}
