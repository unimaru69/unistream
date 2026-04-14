import Foundation
import os

/// Manages EPG program reminders with in-app alerts on tvOS.
/// tvOS does not support visual push notifications — uses a periodic timer
/// to fire alerts while the app is in the foreground.
@MainActor @Observable
final class EPGReminderService {
    private let logger = Logger(subsystem: "fr.unimaru.unistream.tv", category: "Reminders")

    private(set) var reminders: [EPGReminder] = []

    /// The most recently fired alert, observed by the UI to show a toast.
    var pendingAlert: EPGReminder?

    private var checkTimer: Timer?
    private var firedAlertIds: Set<String> = []

    private static let storageKey = "epg_reminders_v1"

    // MARK: - Initialize

    func initialize() {
        load()
        cleanExpired()
        startTimer()
    }

    func shutdown() {
        checkTimer?.invalidate()
        checkTimer = nil
    }

    private func startTimer() {
        checkTimer?.invalidate()
        checkTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.check()
            }
        }
    }

    // MARK: - CRUD

    /// Add a reminder for a program.
    func add(_ reminder: EPGReminder) {
        reminders.removeAll { $0.id == reminder.id }
        reminders.append(reminder)
        save()
        logger.info("Reminder added: \(reminder.programTitle) on \(reminder.channelName)")
    }

    /// Remove a reminder by ID.
    func remove(id: String) {
        reminders.removeAll { $0.id == id }
        firedAlertIds.remove(id)
        save()
        logger.info("Reminder removed: \(id)")
    }

    /// Check if a reminder exists for a program.
    func hasReminder(streamId: String, startUtc: Date) -> Bool {
        let id = EPGReminder.makeId(streamId: streamId, startUtc: startUtc)
        return reminders.contains { $0.id == id }
    }

    /// Toggle reminder for a program — returns true if added, false if removed.
    @discardableResult
    func toggle(streamId: String, channelName: String, program: EpgProgram) -> Bool {
        guard let startUtc = program.start else { return false }
        let id = EPGReminder.makeId(streamId: streamId, startUtc: startUtc)

        if reminders.contains(where: { $0.id == id }) {
            remove(id: id)
            return false
        } else {
            let reminder = EPGReminder(
                streamId: streamId,
                channelName: channelName,
                programTitle: program.title,
                startUtc: startUtc,
                durationMin: program.durationMinutes,
                alertMinutesBefore: 5
            )
            add(reminder)
            return true
        }
    }

    /// Dismiss the current pending alert.
    func dismissAlert() {
        pendingAlert = nil
    }

    // MARK: - Timer Check

    private func check() {
        cleanExpired()
        let now = Date()
        for reminder in reminders {
            guard !firedAlertIds.contains(reminder.id) else { continue }
            if now >= reminder.alertTime && now < reminder.startUtc {
                firedAlertIds.insert(reminder.id)
                pendingAlert = reminder
                logger.info("Alert fired: \(reminder.programTitle)")
            }
        }
    }

    // MARK: - Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([EPGReminder].self, from: data)
        else { return }
        reminders = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(reminders) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    private func cleanExpired() {
        let before = reminders.count
        reminders.removeAll { $0.isExpired }
        if reminders.count != before {
            save()
        }
    }
}

// MARK: - Model

struct EPGReminder: Codable, Identifiable {
    let streamId: String
    let channelName: String
    let programTitle: String
    let startUtc: Date
    let durationMin: Int
    let alertMinutesBefore: Int

    var id: String { Self.makeId(streamId: streamId, startUtc: startUtc) }
    var alertTime: Date { startUtc.addingTimeInterval(-Double(alertMinutesBefore) * 60) }
    var isExpired: Bool { Date() > startUtc }

    static func makeId(streamId: String, startUtc: Date) -> String {
        "\(streamId)_\(Int(startUtc.timeIntervalSince1970))"
    }
}
