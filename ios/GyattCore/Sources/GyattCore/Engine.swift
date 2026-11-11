import Foundation

/// The game rules, ported one-to-one from the web app's `index.html` and kept identical to the
/// Android `Engine.kt`. Pure functions: pass `now` and `calendar` so tests are deterministic.
public enum Engine {
    public static let dailyMinutes = 25
    /// 20+ minutes picked counts as a full day.
    public static let fullDayMinutes = dailyMinutes - 5
    public static let logDays = 30
    public static let never = 999
    public static let maxDaresPerDay = 3
    /// What the guesser earns for a dare that lands.
    public static let dareGuesserPoints = 10
    /// What the doer earns per person who dared the chore they did.
    public static let dareDoerPoints = 5
    public static let adminCodeHash: UInt32 = 1305456521
    private static let dayMs = 86_400_000.0

    // MARK: Card engine

    /// Whole days since this player's most recent approved log of this chore; `never` if never.
    public static func neglectDays(choreId: String, playerId: String, logs: [ChoreLog], now: Date) -> Int {
        let last = logs.lazy.filter { $0.playerId == playerId && $0.choreId == choreId && $0.status == Status.approved }
            .map(\.timestamp).max()
        guard let last else { return never }
        return Int((now.timeIntervalSince(last) * 1000 / dayMs).rounded(.down))
    }

    public static func enrich(_ chore: Chore, days: Int) -> EnrichedChore {
        var tier = 0
        for i in stride(from: chore.tierDays.count - 1, through: 0, by: -1) where days >= chore.tierDays[i] { tier = i; break }
        return EnrichedChore(chore: chore, neglectDays: days, currentMinutes: chore.tiers[tier], escalLevel: tier)
    }

    /// The picker list: most neglected first, then shortest first (ties keep pool order).
    public static func pickableChores(pool: [Chore], playerId: String, logs: [ChoreLog], now: Date) -> [EnrichedChore] {
        stableSorted(pool.map { enrich($0, days: neglectDays(choreId: $0.id, playerId: playerId, logs: logs, now: now)) }) { a, b in
            if a.neglectDays != b.neglectDays { return a.neglectDays > b.neglectDays ? .orderedAscending : .orderedDescending }
            if a.currentMinutes != b.currentMinutes { return a.currentMinutes < b.currentMinutes ? .orderedAscending : .orderedDescending }
            return .orderedSame
        }
    }

    /// Top a selection up to `cap` minutes: same category as something already picked first,
    /// then most neglected, then longest. Returns picked ids followed by the added ones.
    public static func suggestFill(pickedIds: [String], pool: [EnrichedChore], cap: Int = dailyMinutes) -> [String] {
        var result = pickedIds
        let pickedSet = Set(pickedIds)
        let picked = pool.filter { pickedSet.contains($0.id) }
        let cats = Set(picked.map(\.cat))
        var total = picked.reduce(0) { $0 + $1.currentMinutes }
        let candidates = stableSorted(pool.filter { !pickedSet.contains($0.id) }) { a, b in
            let aa = cats.contains(a.cat) ? 1 : 0, bb = cats.contains(b.cat) ? 1 : 0
            if aa != bb { return aa > bb ? .orderedAscending : .orderedDescending }
            if a.neglectDays != b.neglectDays { return a.neglectDays > b.neglectDays ? .orderedAscending : .orderedDescending }
            if a.currentMinutes != b.currentMinutes { return a.currentMinutes > b.currentMinutes ? .orderedAscending : .orderedDescending }
            return .orderedSame
        }
        for c in candidates where total + c.currentMinutes <= cap { result.append(c.id); total += c.currentMinutes }
        return result
    }

    /// Whether the picker's lock-in button is active.
    public static func cardReady(chosen: [EnrichedChore], pool: [EnrichedChore], bonus: Bool) -> Bool {
        if chosen.isEmpty { return false }
        if bonus { return true }
        let total = chosen.reduce(0) { $0 + $1.currentMinutes }
        let ids = Set(chosen.map(\.id))
        let minUnpicked = pool.filter { !ids.contains($0.id) }.map(\.currentMinutes).min() ?? Int.max
        return total >= fullDayMinutes || minUnpicked > dailyMinutes - total
    }

    // MARK: XP / rank / streak

    public static func momentumMult(_ streak: Int) -> Double { 1 + Double(min(streak, 10)) * 0.1 }
    public static func xpToNext(_ level: Int) -> Int { 60 + (level - 1) * 20 }
    public static func toVersion(_ level: Int) -> String { "v\((level - 1) / 10 + 1).\((level - 1) % 10)" }

    /// Approved logs for a player, one per chore per local day (extra rows are sync duplicates).
    public static func approvedOncePerDay(playerId: String, logs: [ChoreLog], calendar: Calendar) -> [(day: Date, log: ChoreLog)] {
        struct Key: Hashable { let day: Date; let chore: String }
        var seen = Set<Key>()
        var out: [(Date, ChoreLog)] = []
        // Newest first, first seen wins, as in the web app.
        for l in stableSorted(logs, by: { a, b in a.timestamp == b.timestamp ? .orderedSame : (a.timestamp > b.timestamp ? .orderedAscending : .orderedDescending) })
        where l.playerId == playerId && l.status == Status.approved {
            let day = calendar.startOfDay(for: l.timestamp)
            if seen.insert(Key(day: day, chore: l.choreId)).inserted { out.append((day, l)) }
        }
        return out
    }

    /// Lifetime XP: approved points per day, each day scaled by its running-streak multiplier.
    public static func xp(playerId: String, logs: [ChoreLog], calendar: Calendar) -> Int {
        var byDay: [Date: Int] = [:]
        for (day, log) in approvedOncePerDay(playerId: playerId, logs: logs, calendar: calendar) { byDay[day, default: 0] += log.points }
        var xp = 0, run = 0
        var prev: Date?
        for day in byDay.keys.sorted() {
            if let p = prev, calendar.date(byAdding: .day, value: 1, to: p) == day { run += 1 } else { run = 1 }
            xp += jsRound(Double(byDay[day]!) * momentumMult(run - 1))
            prev = day
        }
        return xp
    }

    public static func rank(xp: Int) -> Rank {
        var level = 1, into = xp
        while into >= xpToNext(level) { into -= xpToNext(level); level += 1 }
        let need = xpToNext(level)
        return Rank(level: level, version: toVersion(level), nextVersion: toVersion(level + 1), into: into, need: need,
                    pct: jsRound(Double(into) / Double(need) * 100))
    }

    /// Consecutive days, counting back from today, with at least one approved log.
    public static func streak(playerId: String, logs: [ChoreLog], now: Date, calendar: Calendar) -> Int {
        let days = Set(logs.filter { $0.playerId == playerId && $0.status == Status.approved }.map { calendar.startOfDay(for: $0.timestamp) })
        var d = calendar.startOfDay(for: now), n = 0
        while n < 365, days.contains(d) { n += 1; d = calendar.date(byAdding: .day, value: -1, to: d)! }
        return n
    }

    // MARK: Dares

    public static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    /// A dare lands when its target has an approved log of that chore on that day.
    public static func dareLanded(_ d: Dare, logs: [ChoreLog], calendar: Calendar) -> Bool {
        logs.contains { $0.playerId == d.target && $0.choreId == d.choreId && $0.status == Status.approved && dayKey($0.timestamp, calendar: calendar) == d.day }
    }

    /// Dares settle at midnight: only days before `today` (yyyy-MM-dd) are revealed and scored.
    public static func settled(_ d: Dare, today: String) -> Bool { d.day < today }

    /// Points a player earned from one dare, as guesser and/or doer. 0 unless it landed.
    public static func darePoints(playerId: String, _ d: Dare, logs: [ChoreLog], calendar: Calendar) -> Int {
        guard dareLanded(d, logs: logs, calendar: calendar) else { return 0 }
        return (d.from == playerId ? dareGuesserPoints : 0) + (d.target == playerId ? dareDoerPoints : 0)
    }

    /// Lifetime XP from settled dares. Flat points on top of chore XP (no streak multiplier).
    public static func dareXp(playerId: String, dares: [Dare], logs: [ChoreLog], today: String, calendar: Calendar) -> Int {
        dares.filter { settled($0, today: today) && ($0.from == playerId || $0.target == playerId) }
            .reduce(0) { $0 + darePoints(playerId: playerId, $1, logs: logs, calendar: calendar) }
    }

    /// Why `from` can't add this dare, or nil if they can.
    public static func dareBlocked(from: String, target: String, mineToday: [Dare], targetSubmitted: Bool) -> String? {
        if from == target { return "you can't dare yourself" }
        if targetSubmitted { return "locked — they already submitted today" }
        if mineToday.count >= maxDaresPerDay { return "that's all \(maxDaresPerDay) dares for today" }
        return nil
    }

    /// Monday of the week containing `today`.
    public static func weekStart(_ today: Date, calendar: Calendar) -> Date {
        let day = calendar.startOfDay(for: today)
        let weekday = calendar.component(.weekday, from: day) // 1 = Sunday
        return calendar.date(byAdding: .day, value: -((weekday + 5) % 7), to: day)!
    }

    /// This week's leaderboard score: approved chore points since Monday plus settled dare points.
    public static func weekPoints(playerId: String, logs: [ChoreLog], dares: [Dare], now: Date, calendar: Calendar) -> Int {
        let start = weekStart(now, calendar: calendar), startKey = dayKey(start, calendar: calendar), today = dayKey(now, calendar: calendar)
        let chores = approvedOncePerDay(playerId: playerId, logs: logs, calendar: calendar).filter { $0.day >= start }.reduce(0) { $0 + $1.log.points }
        let fromDares = dares.filter { settled($0, today: today) && $0.day >= startKey }.reduce(0) { $0 + darePoints(playerId: playerId, $1, logs: logs, calendar: calendar) }
        return chores + fromDares
    }

    // MARK: Daily minutes log

    /// Minutes a log contributed: its recorded minutes, else the chore's base tier, else its points.
    public static func choreMinutes(_ log: ChoreLog, pool: [String: Chore]) -> Int {
        log.minutes ?? pool[log.choreId]?.tiers.first ?? log.points
    }

    public static func minutesByDay(playerId: String, logs: [ChoreLog], pool: [String: Chore], calendar: Calendar) -> [Date: Int] {
        var byDay: [Date: Int] = [:]
        for (day, log) in approvedOncePerDay(playerId: playerId, logs: logs, calendar: calendar) { byDay[day, default: 0] += choreMinutes(log, pool: pool) }
        return byDay
    }

    /// The last `logDays` local day starts, oldest first, today last.
    public static func recentDays(now: Date, calendar: Calendar) -> [Date] {
        let today = calendar.startOfDay(for: now)
        return (0..<logDays).reversed().map { calendar.date(byAdding: .day, value: -$0, to: today)! }
    }

    /// Opacity of a daily-log cell: 0 for none, faded for partial, 1 for a full 25-minute day.
    public static func cellAlpha(_ mins: Int) -> Double {
        if mins <= 0 { return 0 }
        if mins >= dailyMinutes { return 1 }
        return 0.30 + Double(mins) / Double(dailyMinutes) * 0.70
    }

    // MARK: Admin gate

    /// 32-bit FNV-1a over UTF-16 code units, matching the web app's `hashCode`.
    public static func fnv1a(_ s: String) -> UInt32 {
        var h: UInt32 = 2166136261
        for u in s.utf16 { h ^= UInt32(u); h = h &* 16777619 }
        return h
    }

    // MARK: Helpers

    /// JavaScript's Math.round: halves round up.
    static func jsRound(_ x: Double) -> Int { Int((x + 0.5).rounded(.down)) }

    /// Swift's sort is not documented as stable; the web app and Android rely on stable sorting.
    static func stableSorted<T>(_ items: [T], by compare: (T, T) -> ComparisonResult) -> [T] {
        items.enumerated().sorted { a, b in
            switch compare(a.element, b.element) {
            case .orderedAscending: return true
            case .orderedDescending: return false
            case .orderedSame: return a.offset < b.offset
            }
        }.map(\.element)
    }
}
