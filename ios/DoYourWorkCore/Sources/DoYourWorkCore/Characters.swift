import Foundation

/// One of the little characters a player can have on their scoreboard tile. It's a stack of layers
/// on a `Characters.size` square, painted in order: the dark body, then the light details (eyes,
/// teeth, a headband), with the odd body layer on top for a pupil.
public struct PlayerCharacter: Identifiable, Hashable, Sendable {
    public struct Layer: Hashable, Sendable {
        public let detail: Bool
        public let path: String
    }
    public let id: String
    public let name: String
    public let layers: [Layer]
}

/// The characters, who gets which, and how the scoreboard lays its tiles out. The same on Android.
public enum Characters {
    public static let size: Double = 40

    /// The drawings themselves are in `CharacterArt`, written out from `tools/characters`.
    public static var all: [PlayerCharacter] { CharacterArt.all }

    /// The characters handed out to someone who hasn't picked: the first sixteen, the ones every
    /// version has. Characters added later can be picked but aren't handed out, so nobody's
    /// character changes when the app updates, and phones on different versions still agree.
    public static let givenCount = 16
    public static var given: [PlayerCharacter] { Array(all.prefix(givenCount)) }

    /// The character with this id; nil for none, or one this version doesn't know.
    public static func named(_ id: String?) -> PlayerCharacter? {
        guard let id else { return nil }
        return all.first { $0.id == id }
    }

    /// Who has which character. Someone who picked one has it. Everyone else is given one from
    /// their username, so it's the same on every phone: a character named in it if there is one
    /// ("sockninja" starts as the ninja), else one the username's hash lands on, or the next free
    /// one. Only the `given` characters are handed out this way, and only once there are more
    /// players than those do two share.
    public static func assign(_ players: [Player]) -> [String: PlayerCharacter] {
        var out: [String: PlayerCharacter] = [:]
        var taken = Set<String>()
        for p in players {
            if let c = named(p.character) { out[p.id] = c; taken.insert(c.id) }
        }
        // In id order, so two phones holding the list in a different order still agree.
        let ordered = players.sorted { (Int($0.id) ?? Int.max, $0.id) < (Int($1.id) ?? Int.max, $1.id) }
        for p in ordered where out[p.id] == nil {
            let lowered = p.name.lowercased()
            let pool = given
            let start = Int(Engine.fnv1a(p.name) % UInt32(pool.count))
            let pick = pool.first { lowered.contains($0.id) && !taken.contains($0.id) }
                ?? (0..<pool.count).map { pool[(start + $0) % pool.count] }.first { !taken.contains($0.id) }
                ?? pool[start]
            out[p.id] = pick; taken.insert(pick.id)
        }
        return out
    }

    /// How many tiles go on each row of the scoreboard: as few rows as `perRow` allows, filled as
    /// evenly as they can be, so four players are two and two rather than three and one.
    public static func tileRows(_ count: Int, perRow: Int) -> [Int] {
        guard count > 0, perRow > 0 else { return [] }
        let rows = (count + perRow - 1) / perRow
        return (0..<rows).map { count / rows + ($0 < count % rows ? 1 : 0) }
    }

    /// One step of a drawing. Coordinates are in the `size` square.
    public enum Step: Equatable, Sendable {
        case move(Double, Double)
        case line(Double, Double)
        case quad(Double, Double, Double, Double)
        case cubic(Double, Double, Double, Double, Double, Double)
        case close
    }

    /// Reads a layer's path. The drawings only ever use absolute M, L, Q, C and Z with spaces
    /// between everything, so this is all the reading there is; anything else stops the drawing there.
    public static func steps(_ path: String) -> [Step] {
        var out: [Step] = []
        let t = path.split(separator: " ")
        var i = 0
        func take(_ n: Int) -> [Double]? {
            guard i + n <= t.count else { return nil }
            var v: [Double] = []
            for token in t[i..<(i + n)] { guard let d = Double(token) else { return nil }; v.append(d) }
            i += n
            return v
        }
        while i < t.count {
            let letter = t[i]; i += 1
            switch letter {
            case "M": guard let v = take(2) else { return out }; out.append(.move(v[0], v[1]))
            case "L": guard let v = take(2) else { return out }; out.append(.line(v[0], v[1]))
            case "Q": guard let v = take(4) else { return out }; out.append(.quad(v[0], v[1], v[2], v[3]))
            case "C": guard let v = take(6) else { return out }; out.append(.cubic(v[0], v[1], v[2], v[3], v[4], v[5]))
            case "Z": out.append(.close)
            default: return out
            }
        }
        return out
    }
}
