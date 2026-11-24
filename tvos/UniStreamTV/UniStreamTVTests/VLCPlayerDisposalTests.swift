import XCTest
import VLCKitSPM
@testable import UniStreamTV

@MainActor
final class VLCPlayerDisposalTests: XCTestCase {
    /// The disposal queue must end up holding the last reference, so libvlc
    /// is destroyed there and not when the main thread lets go of the player.
    func testPlayingPlayerIsStoppedAndFreedAfterHandover() async throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "ac3-5.1", withExtension: "mka"))
        weak var released: VLCMediaPlayer?
        do {
            let player = VLCMediaPlayer(options: ["--no-spdif", "--no-video"])
            player.media = VLCMedia(url: url)
            player.play()
            try await Task.sleep(for: .milliseconds(500))
            released = player
            VLCPlayerDisposal.stopAndRelease(player)
        }
        // Main no longer owns it, yet it must still be alive: the queue is
        // holding it while VLCKit's trailing main-queue callbacks drain.
        XCTAssertNotNil(released, "Player was freed on the main thread's release")
        for _ in 0..<50 where released != nil {
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertNil(released, "Player was never freed")
    }
}
