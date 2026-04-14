import XCTest
@testable import UniStreamTV

final class EPGReminderTests: XCTestCase {

    func testIdGeneration() {
        let date = Date(timeIntervalSince1970: 1700000000)
        let id = EPGReminder.makeId(streamId: "ch_42", startUtc: date)
        XCTAssertEqual(id, "ch_42_1700000000")
    }

    func testIdConsistency() {
        let date = Date(timeIntervalSince1970: 1234567890)
        let reminder = EPGReminder(
            streamId: "live_5",
            channelName: "France 2",
            programTitle: "JT",
            startUtc: date,
            durationMin: 30,
            alertMinutesBefore: 5
        )
        XCTAssertEqual(reminder.id, EPGReminder.makeId(streamId: "live_5", startUtc: date))
    }

    func testAlertTimeIsFiveMinutesBefore() {
        let start = Date(timeIntervalSince1970: 1700000000)
        let reminder = EPGReminder(
            streamId: "1", channelName: "Ch", programTitle: "P",
            startUtc: start, durationMin: 60, alertMinutesBefore: 5
        )
        XCTAssertEqual(reminder.alertTime, start.addingTimeInterval(-300))
    }

    func testCustomAlertMinutes() {
        let start = Date(timeIntervalSince1970: 1700000000)
        let reminder = EPGReminder(
            streamId: "1", channelName: "Ch", programTitle: "P",
            startUtc: start, durationMin: 60, alertMinutesBefore: 10
        )
        XCTAssertEqual(reminder.alertTime, start.addingTimeInterval(-600))
    }

    func testFutureReminderNotExpired() {
        let future = Date().addingTimeInterval(3600)
        let reminder = EPGReminder(
            streamId: "1", channelName: "Ch", programTitle: "P",
            startUtc: future, durationMin: 30, alertMinutesBefore: 5
        )
        XCTAssertFalse(reminder.isExpired)
    }

    func testPastReminderIsExpired() {
        let past = Date().addingTimeInterval(-3600)
        let reminder = EPGReminder(
            streamId: "1", channelName: "Ch", programTitle: "P",
            startUtc: past, durationMin: 30, alertMinutesBefore: 5
        )
        XCTAssertTrue(reminder.isExpired)
    }
}
