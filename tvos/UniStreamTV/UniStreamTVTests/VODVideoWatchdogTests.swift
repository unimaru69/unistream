import XCTest
@testable import UniStreamTV

@MainActor
final class VODVideoWatchdogTests: XCTestCase {
    func testNetworkBufferingNeverDisablesHardwareDecoding() {
        XCTAssertFalse(VLCPlayerViewController.shouldRetryVideoDecoder(
            isPlaying: false, alreadyRetried: false, hasVideoSize: false,
            decodedVideo: 0, playedAudioBuffers: 100))
    }

    func testDiscoveredAudioTrackWithoutSoundIsNotDecoderFailure() {
        XCTAssertFalse(VLCPlayerViewController.shouldRetryVideoDecoder(
            isPlaying: true, alreadyRetried: false, hasVideoSize: false,
            decodedVideo: 0, playedAudioBuffers: 0))
    }

    func testAudioPlayingWithoutAnyVideoCanRetry() {
        XCTAssertTrue(VLCPlayerViewController.shouldRetryVideoDecoder(
            isPlaying: true, alreadyRetried: false, hasVideoSize: false,
            decodedVideo: 0, playedAudioBuffers: 100))
    }

    func testDecodedVideoWithoutReportedSizeDoesNotRetry() {
        XCTAssertFalse(VLCPlayerViewController.shouldRetryVideoDecoder(
            isPlaying: true, alreadyRetried: false, hasVideoSize: false,
            decodedVideo: 100, playedAudioBuffers: 100))
    }

    func testRetryBudgetAndVisibleVideoPreventRetry() {
        XCTAssertFalse(VLCPlayerViewController.shouldRetryVideoDecoder(
            isPlaying: true, alreadyRetried: true, hasVideoSize: false,
            decodedVideo: 0, playedAudioBuffers: 100))
        XCTAssertFalse(VLCPlayerViewController.shouldRetryVideoDecoder(
            isPlaying: true, alreadyRetried: false, hasVideoSize: true,
            decodedVideo: 0, playedAudioBuffers: 100))
    }
}
