import XCTest
import UIKit
import VLCKitSPM

/// Real decoder/output tests using generated sine-wave clips, with no network
/// or client media. Track discovery alone passed even in the silent build 80;
/// these checks require decoded audio AND PCM buffers reaching the output.
@MainActor
final class TrueHDAudioDecodeTests: XCTestCase {
    /// CI builds against the upstream VLCKit, which has no MLP/TrueHD decoder
    /// (see scripts/ci-tvos-upstream-vlc.sh). Local and release builds use
    /// the TrueHD-enabled package and must run these tests.
    private func skipWithoutTrueHDDecoder() throws {
        try XCTSkipIf(ProcessInfo.processInfo.environment["UNISTREAM_UPSTREAM_VLC"] == "1",
                      "Upstream VLCKit has no TrueHD decoder")
    }

    private func makePlayer(fixture: String) throws -> VLCMediaPlayer {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: fixture, withExtension: "mka"))
        let player = VLCMediaPlayer(options: ["--no-spdif", "--no-video"])
        player.media = VLCMedia(url: url)
        return player
    }

    private func waitForAudio(_ player: VLCMediaPlayer, after decoded: Int32 = 0,
                              played: Int32 = 0) async throws {
        for _ in 0..<30 {
            try await Task.sleep(for: .milliseconds(100))
            if let stats = player.media?.statistics,
               stats.decodedAudio > decoded, stats.playedAudioBuffers > played {
                return
            }
        }
        let stats = try XCTUnwrap(player.media?.statistics)
        XCTAssertGreaterThan(stats.decodedAudio, decoded, "Audio track found but not decoded")
        XCTAssertGreaterThan(stats.playedAudioBuffers, played, "Decoded audio never reached the output")
    }

    func testTrueHDProducesAudio() async throws {
        try skipWithoutTrueHDDecoder()
        let player = try makePlayer(fixture: "truehd-5.1")
        player.play()
        defer { player.stop() }
        try await waitForAudio(player)
    }

    func testDolbyDigitalStillProducesAudio() async throws {
        let player = try makePlayer(fixture: "ac3-5.1")
        player.play()
        defer { player.stop() }
        try await waitForAudio(player)
    }

    func testDTSStillProducesAudio() async throws {
        let player = try makePlayer(fixture: "dts-5.1")
        player.play()
        defer { player.stop() }
        try await waitForAudio(player)
    }

    func testSwitchFromFrenchAC3ToEnglishTrueHDThenStereo() async throws {
        try skipWithoutTrueHDDecoder()
        let player = try makePlayer(fixture: "ac3-truehd-switch")
        player.play()
        defer { player.stop() }
        try await waitForAudio(player)
        let tracks = try XCTUnwrap(player.media?.tracksInformation as? [[String: Any]])
        let english = try XCTUnwrap(tracks.first {
            ($0[VLCMediaTracksInformationType] as? String) == VLCMediaTracksInformationTypeAudio
                && ($0[VLCMediaTracksInformationLanguage] as? String) == "eng"
        })
        let id = try XCTUnwrap(english[VLCMediaTracksInformationId] as? NSNumber).int32Value
        player.currentAudioTrackIndex = id
        try await Task.sleep(for: .milliseconds(300))
        player.audioChannel = 1 // Same stereo downmix as the app's compatibility option.
        // Drain the previous French decoder/output queue. Counting buffers
        // immediately after the switch would let the silent old build pass.
        try await Task.sleep(for: .seconds(1))
        let before = try XCTUnwrap(player.media?.statistics)
        try await waitForAudio(player, after: before.decodedAudio, played: before.playedAudioBuffers)
        XCTAssertEqual(player.currentAudioTrackIndex, id)
    }

    func testMKVVideoAndTrueHDAudioPlayTogether() async throws {
        try skipWithoutTrueHDDecoder()
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "h264-truehd", withExtension: "mkv"))
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let host = try XCTUnwrap(scene.windows.first?.rootViewController?.view)
        let drawable = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 180))
        host.addSubview(drawable)
        let player = VLCMediaPlayer(options: ["--no-spdif"])
        player.drawable = drawable
        player.media = VLCMedia(url: url)
        player.play()
        defer {
            player.stop()
            player.drawable = nil
            drawable.removeFromSuperview()
        }
        for _ in 0..<40 {
            try await Task.sleep(for: .milliseconds(100))
            if let stats = player.media?.statistics,
               stats.decodedVideo > 0, stats.displayedPictures > 0,
               stats.decodedAudio > 0, stats.playedAudioBuffers > 0 { return }
        }
        let stats = try XCTUnwrap(player.media?.statistics)
        XCTAssertGreaterThan(stats.decodedVideo, 0)
        XCTAssertGreaterThan(stats.displayedPictures, 0)
        XCTAssertGreaterThan(stats.decodedAudio, 0)
        XCTAssertGreaterThan(stats.playedAudioBuffers, 0)
    }
}
