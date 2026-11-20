import Foundation
import UserNotifications
import DoYourWorkCore

/// The two daily notifications (see `Reminders` in DoYourWorkCore for what they say and when).
///
/// iOS only shows notifications the app scheduled ahead, so this keeps the next two weeks scheduled
/// and redoes it whenever the app opens, goes to the background, or a card or chore changes. Today's
/// evening reminder is left out once everyone this phone looks after has picked, so nobody who has
/// already picked gets asked. A phone nobody opens for two weeks goes quiet until it's opened again.
@MainActor
final class ReminderScheduler {
    static let shared = ReminderScheduler()

    /// Debug builds only: `-reminderPreview` lets the reminders run alongside `-uiTesting`'s demo
    /// family, with today's two moved to 30 and 60 seconds after the app is left, to watch them on a phone.
    private static let preview = AppStore.launchArguments.contains("-reminderPreview")

    private static let eveningHourKey = "reminders.eveningHour"
    private static let daysAhead = 14

    /// The hour of the evening reminder, kept on this phone.
    static var eveningHour: Int {
        get {
            let h = UserDefaults.standard.object(forKey: eveningHourKey) as? Int ?? Reminders.defaultEveningHour
            return Reminders.eveningHours.contains(h) ? h : Reminders.defaultEveningHour
        }
        set { UserDefaults.standard.set(newValue, forKey: eveningHourKey) }
    }

    /// What was last scheduled, so a sync that changes nothing that matters doesn't redo it all.
    private var lastKey: String?
    private var asked = false

    /// Asks once for permission to notify (iOS shows the question only the first time).
    func askPermission(_ store: AppStore) {
        guard !AppStore.uiTesting || Self.preview, !asked else { return }
        asked = true
        // Reminders added before the answer may not count, so they're added again once it's yes.
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            Task { @MainActor in ReminderScheduler.shared.reschedule(store, force: true) }
        }
    }

    func reschedule(_ store: AppStore, force: Bool = false) {
        guard !AppStore.uiTesting || Self.preview else { return }
        let center = UNUserNotificationCenter.current()
        let watched = Reminders.watched(playerIds: store.players.map(\.id), me: store.me)
        guard store.isSetUp, !watched.isEmpty else {
            lastKey = nil
            center.removeAllPendingNotificationRequests()
            return
        }
        let still = watched.filter {
            !Reminders.hasPicked(card: store.cards["\($0)|\(store.todayKey)"], todaysLogs: store.todaysLogs($0))
        }
        let hour = Self.eveningHour
        let key = "\(store.todayKey)|\(hour)|\(watched)|\(still)"
        guard force || key != lastKey else { return }
        lastKey = key

        let personal = watched == [store.me]
        let names = still.compactMap { id in store.players.first { $0.id == id }.map(store.shownName) }
        let cal = store.calendar
        let now = Date()
        let today = cal.startOfDay(for: now)
        var requests: [UNNotificationRequest] = []
        for offset in 0..<Self.daysAhead {
            guard let day = cal.date(byAdding: .day, value: offset, to: today) else { continue }
            // Today, once everyone here has picked, there's nothing to ask.
            if offset == 0 && still.isEmpty { continue }
            if let at = Self.preview && offset == 0 ? now.addingTimeInterval(30) : cal.date(bySettingHour: Reminders.morningHour, minute: 0, second: 0, of: day), at > now {
                let c = UNMutableNotificationContent()
                c.title = Reminders.lines.randomElement() ?? "DOYOURWORK"
                c.body = Reminders.morningBody
                c.sound = .default
                requests.append(request("morning-\(offset)", c, at, cal))
            }
            if let at = Self.preview && offset == 0 ? now.addingTimeInterval(60) : cal.date(bySettingHour: hour, minute: 0, second: 0, of: day), at > now {
                let c = UNMutableNotificationContent()
                c.title = Reminders.eveningTitle
                // Only today's names are known: on later days anyone may have picked by then.
                c.body = Reminders.eveningBody(stillToPick: offset == 0 ? names : [], personal: personal)
                c.sound = .default
                requests.append(request("evening-\(offset)", c, at, cal))
            }
        }
        center.removeAllPendingNotificationRequests()
        for r in requests { center.add(r) }
    }

    private func request(_ id: String, _ content: UNNotificationContent, _ at: Date, _ cal: Calendar) -> UNNotificationRequest {
        let parts = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: at)
        return UNNotificationRequest(identifier: id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false))
    }
}
