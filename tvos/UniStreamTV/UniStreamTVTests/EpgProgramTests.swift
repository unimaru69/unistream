import XCTest
@testable import UniStreamTV

final class EpgProgramTests: XCTestCase {

    // MARK: - Parsing

    func testParsesEpochTimestamps() {
        let now = Date()
        let start = Int(now.timeIntervalSince1970) - 1800
        let end = Int(now.timeIntervalSince1970) + 1800
        let program = EpgProgram(json: [
            "title": "Test Show",
            "start": "2025-01-01 10:00:00",
            "start_timestamp": start,
            "stop_timestamp": end,
        ])
        XCTAssertEqual(program.title, "Test Show")
        XCTAssertNotNil(program.start)
        XCTAssertNotNil(program.end)
        XCTAssertTrue(program.isCurrent)
    }

    func testParsesStringEpochTimestamps() {
        let start = Int(Date().timeIntervalSince1970) - 3600
        let end = Int(Date().timeIntervalSince1970) - 1800
        let program = EpgProgram(json: [
            "title": "Past Show",
            "start": "",
            "start_timestamp": "\(start)",
            "stop_timestamp": "\(end)",
        ])
        XCTAssertTrue(program.isPast)
        XCTAssertFalse(program.isCurrent)
    }

    func testParsesDateStringFallback() {
        let program = EpgProgram(json: [
            "title": "Show",
            "start": "2020-01-01 10:00:00",
            "end": "2020-01-01 11:00:00",
        ])
        XCTAssertNotNil(program.start)
        XCTAssertNotNil(program.end)
        XCTAssertEqual(program.durationMinutes, 60)
        XCTAssertTrue(program.isPast)
    }

    func testHandlesEmptyJson() {
        let program = EpgProgram(json: [:])
        XCTAssertEqual(program.title, "")
        XCTAssertNil(program.start)
        XCTAssertNil(program.end)
        XCTAssertFalse(program.isCurrent)
        XCTAssertFalse(program.isPast)
        XCTAssertEqual(program.durationMinutes, 0)
        XCTAssertEqual(program.progress, 0)
    }

    // MARK: - Duration

    func testDurationCalculation() {
        let start = Date().timeIntervalSince1970 - 7200
        let end = Date().timeIntervalSince1970 - 3600
        let program = EpgProgram(json: [
            "title": "60min",
            "start": "",
            "start_timestamp": Int(start),
            "stop_timestamp": Int(end),
        ])
        XCTAssertEqual(program.durationMinutes, 60)
    }

    // MARK: - Progress

    func testProgressIsZeroWhenNotCurrent() {
        let future = Int(Date().timeIntervalSince1970) + 3600
        let program = EpgProgram(json: [
            "title": "Future",
            "start": "",
            "start_timestamp": future,
            "stop_timestamp": future + 3600,
        ])
        XCTAssertEqual(program.progress, 0)
    }

    func testProgressIsNonZeroWhenCurrent() {
        let start = Int(Date().timeIntervalSince1970) - 1800
        let end = Int(Date().timeIntervalSince1970) + 1800
        let program = EpgProgram(json: [
            "title": "Now",
            "start": "",
            "start_timestamp": start,
            "stop_timestamp": end,
        ])
        XCTAssertGreaterThan(program.progress, 0.4)
        XCTAssertLessThan(program.progress, 0.6)
    }

    // MARK: - Server Local Start

    func testServerLocalStartPreserved() {
        let program = EpgProgram(json: [
            "title": "Show",
            "start": "2025-06-15 20:30:00",
            "start_timestamp": 1750021800,
            "stop_timestamp": 1750025400,
        ])
        XCTAssertEqual(program.serverLocalStart, "2025-06-15 20:30:00")
    }
}
