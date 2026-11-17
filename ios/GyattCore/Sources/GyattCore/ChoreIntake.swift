import Foundation

/// Turns what someone typed or said about their household — "we need to do the dishes, take out
/// the trash and someone has to feed the dog for 5 minutes" — into a list of chores.
///
/// It is plain word-sorting that runs on the device: nothing is sent anywhere to be understood.
/// It won't get everything right, and doesn't need to: the result is shown as a list to tick,
/// rename and re-time before anything is added.
public enum ChoreIntake {
    public static let maxNameLength = 40
    public static let maxChoresPerPass = 60
    /// A chore has to fit on a day's card.
    public static let minuteRange = 1...Engine.dailyMinutes

    // MARK: Public

    /// The chores found in `text`, leaving out any already on the list (matched by name).
    public static func parse(_ text: String, existing: [Chore] = []) -> [Chore] {
        var names = Set(existing.map { key($0.name) })
        var ids = Set(existing.map(\.id))
        var out: [Chore] = []
        for found in split(text) where out.count < maxChoresPerPass {
            guard names.insert(key(found.name)).inserted else { continue }
            let chore = make(name: found.name, minutes: found.minutes ?? guessMinutes(found.name), takenIds: ids)
            ids.insert(chore.id)
            out.append(chore)
        }
        return out
    }

    /// A chore from a name and how long it takes. Left undone, it grows to one and a half times and
    /// then twice as long, like the starter chores do, but never past a day's card.
    public static func make(name: String, minutes: Int, takenIds: Set<String> = [], id: String? = nil) -> Chore {
        let m = min(max(minutes, minuteRange.lowerBound), minuteRange.upperBound)
        let cap = minuteRange.upperBound
        let tiers = [m, min(cap, (m * 3 + 1) / 2), min(cap, m * 2)]
        let clean = tidyName(name) ?? "chore"
        return Chore(id: id ?? uniqueId(for: clean, taken: takenIds), name: clean, cat: category(clean),
                     pts: max(5, Engine.jsRound(Double(m) * 2.5)), tiers: tiers, tierDays: [0, 3, 7])
    }

    /// A name as it will be stored: lower case like the rest of the app, single spaces, not too long.
    /// Nil if there's nothing in it to read.
    public static func tidyName(_ raw: String) -> String? {
        let words = raw.lowercased().split(whereSeparator: \.isWhitespace).map(String.init)
        var name = ""
        for word in words {
            let next = name.isEmpty ? word : name + " " + word
            if next.count > maxNameLength { break }
            name = next
        }
        if name.isEmpty, let first = words.first { name = String(first.prefix(maxNameLength)) }
        return name.contains(where: \.isLetter) ? name : nil
    }

    /// The pieces of `text` that read as chores, in order, with any time that was mentioned.
    public static func split(_ text: String) -> [(name: String, minutes: Int?)] {
        var out: [(name: String, minutes: Int?)] = []
        let separators: Set<Character> = ["\n", "\r", ",", ";", ".", "!", "?", "•", "·", "\t", ":"]
        // Phones type a curly apostrophe; the word lists below use the plain one.
        let plain = text.lowercased().replacingOccurrences(of: "\u{2019}", with: "'")
        for piece in plain.split(whereSeparator: { separators.contains($0) }) {
            let words = piece.split(whereSeparator: \.isWhitespace).map(trimmed).filter { !$0.isEmpty }
            for fragment in fragments(words) {
                var words = fragment
                let minutes = takeMinutes(&words)
                stripEnds(&words)
                guard let name = tidyName(words.joined(separator: " ")), name.count >= 3, !fillers.contains(name),
                      let last = words.last, !danglers.contains(last) else { continue }
                out.append((name, minutes))
            }
        }
        return out
    }

    /// A first guess at how long a chore takes, from the words in its name. Five minutes if none ring a bell.
    public static func guessMinutes(_ name: String) -> Int {
        let n = key(name)
        return minuteGuesses.first { n.contains($0.0) }?.1 ?? 5
    }

    /// The part of the house a chore belongs to; picking a card tries to mix these.
    public static func category(_ name: String) -> String {
        let n = key(name)
        return categories.first { $0.1.contains { n.contains($0) } }?.0 ?? "other"
    }

    // MARK: Splitting

    /// Words that start a new chore wherever they appear.
    private static let breakers: Set<String> = ["then", "also", "plus", "next"]

    /// Words a chore tends to start with. Used to tell "wash the dishes and take out the trash"
    /// (two chores) from "pick up toys and books" (one), and to cut a run of speech that came
    /// through with no punctuation.
    private static let verbs: Set<String> = [
        "take", "wash", "vacuum", "feed", "fold", "wipe", "sweep", "mop", "make", "empty", "unload", "load",
        "walk", "pick", "put", "tidy", "dust", "scrub", "do", "set", "clear", "sort", "mow", "rake", "change",
        "organize", "brush", "cook", "bring", "hang", "rinse", "dry", "clean", "water", "start", "switch",
        "collect", "fill", "check", "get", "pack", "shovel", "weed", "hoover", "refill", "replace", "straighten",
    ]

    /// A verb straight after one of these is part of the same chore ("put away clean clothes",
    /// "start a load of laundry"), so it never starts a new one.
    private static let glue: Set<String> = [
        "a", "an", "the", "of", "to", "and", "or", "up", "out", "away", "my", "your", "our", "their", "his", "her",
        "in", "on", "off", "for", "with", "all", "some", "any", "down", "back", "&",
    ]

    /// Below this many words a fragment is taken as one chore; above it, it's probably several run together.
    private static let runOnLength = 7

    private static func fragments(_ words: [String]) -> [[String]] {
        var out: [[String]] = [], current: [String] = []
        func cut() { if !current.isEmpty { out.append(current); current = [] } }
        let runOn = words.count >= runOnLength
        for (i, word) in words.enumerated() {
            if breakers.contains(word) { cut(); continue }
            let nextIsVerb = i + 1 < words.count && verbs.contains(words[i + 1])
            // "…the dishes and take out…": two chores. "fold and put away…": one.
            if word == "and", nextIsVerb, current.count >= 2 { cut(); continue }
            if runOn, verbs.contains(word), current.count >= 2, let last = current.last, !glue.contains(last) { cut() }
            current.append(word)
        }
        cut()
        return out
    }

    // MARK: Minutes

    private static let numberWords: [String: Int] = [
        "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
        "twelve": 12, "fifteen": 15, "twenty": 20, "thirty": 30, "a": 1, "an": 1,
    ]
    private static let minuteUnits: Set<String> = ["min", "mins", "minute", "minutes"]
    private static let hourUnits: Set<String> = ["hour", "hours", "hr", "hrs"]
    /// Words that lead into a time and go with it: "takes about ten minutes".
    private static let timeLeadIns: Set<String> = ["for", "takes", "take", "about", "around", "roughly", "is", "it", "that", "which", "like", "each"]

    /// Finds "10 minutes", "ten min", "10m", "half an hour" in `words`, removes it, and returns the minutes.
    private static func takeMinutes(_ words: inout [String]) -> Int? {
        var found: (range: Range<Int>, minutes: Int)?
        for (i, word) in words.enumerated() {
            // "10m", "10min", "10mins"
            if let unit = ["minutes", "minute", "mins", "min", "m"].first(where: { word.hasSuffix($0) }),
               let n = Int(word.dropLast(unit.count)), !word.dropLast(unit.count).isEmpty {
                found = (i..<i + 1, n); break
            }
            guard i + 1 < words.count, let n = Int(word) ?? numberWords[word] else { continue }
            if minuteUnits.contains(words[i + 1]) { found = (i..<i + 2, n); break }
            if hourUnits.contains(words[i + 1]) {
                let half = i > 0 && words[i - 1] == "half"
                found = ((half ? i - 1 : i)..<i + 2, half ? 30 : n * 60); break
            }
        }
        guard var hit = found else { return nil }
        while hit.range.lowerBound > 0, timeLeadIns.contains(words[hit.range.lowerBound - 1]) {
            hit.range = (hit.range.lowerBound - 1)..<hit.range.upperBound
        }
        words.removeSubrange(hit.range)
        return min(max(hit.minutes, minuteRange.lowerBound), minuteRange.upperBound)
    }

    // MARK: Trimming

    /// Ways people lead into a chore when talking: dropped from the front, repeatedly.
    private static let leadIns: [[String]] = [
        "the kids need to", "the kids have to", "the kids should", "kids need to", "kids have to",
        "someone needs to", "someone has to", "somebody needs to", "somebody has to", "someone should",
        "we need to", "we have to", "we got to", "we gotta", "we should", "we also", "we always", "we usually",
        "you need to", "you have to", "i need to", "i have to", "they need to", "they have to",
        "there is", "there's", "need to", "needs to", "have to", "has to", "got to", "gotta", "should",
        "please", "and", "also", "then", "or", "um", "uh", "oh", "okay", "ok", "so", "well", "like",
        "first", "second", "third", "finally", "lastly", "to", "we", "i", "-", "*",
    ].map { $0.split(separator: " ").map(String.init) }.sorted { $0.count > $1.count }

    /// How-often words at the end say nothing about what the chore is.
    private static let trailers: [[String]] = [
        "every single day", "every day", "every morning", "every night", "every evening", "every week",
        "each day", "each morning", "each night", "each week", "once a day", "once a week", "twice a week",
        "daily", "weekly", "too", "as well", "and", "or", "then", "also", "to", "etc",
    ].map { $0.split(separator: " ").map(String.init) }.sorted { $0.count > $1.count }

    /// Things said around a list that aren't chores.
    private static let fillers: Set<String> = [
        "that's it", "that's all", "thats it", "thats all", "that is it", "that is all", "and so on", "so on",
        "stuff like that", "things like that", "you know", "let's see", "lets see", "i think", "the end", "done",
        "first", "second", "third", "finally", "lastly", "okay", "yeah", "yes", "and", "the", "well", "then", "also",
        "like", "stuff", "things", "etc", "hmm",
    ]

    /// A fragment ending in one of these was introducing the list ("here are our chores:"), not on it.
    private static let danglers: Set<String> = ["chores", "are", "is", "include", "includes", "list"]

    private static func stripEnds(_ words: inout [String]) {
        var changed = true
        while changed {
            changed = false
            // A list number ("1", "2)") or a stray count left at either end.
            while let first = words.first, Int(first) != nil { words.removeFirst(); changed = true }
            while let last = words.last, Int(last) != nil { words.removeLast(); changed = true }
            if let lead = leadIns.first(where: { words.count > $0.count && Array(words.prefix($0.count)) == $0 }) {
                words.removeFirst(lead.count); changed = true
            }
            if let trail = trailers.first(where: { words.count > $0.count && Array(words.suffix($0.count)) == $0 }) {
                words.removeLast(trail.count); changed = true
            }
        }
    }

    /// A word without the punctuation stuck to its ends: "(dishes)" → "dishes". Inner marks stay,
    /// so "trash/recycling" and "kids'" survive.
    private static func trimmed(_ word: Substring) -> String {
        var w = Substring(word)
        func keep(_ c: Character) -> Bool { c.isLetter || c.isNumber }
        while let first = w.first, !keep(first) { w.removeFirst() }
        while let last = w.last, !keep(last) { w.removeLast() }
        return String(w)
    }

    // MARK: Guesses

    /// Checked in order, so the more telling word comes first ("mow" before "yard").
    private static let minuteGuesses: [(String, Int)] = [
        ("mow", 25), ("shovel", 20), ("rake", 20), ("weed", 15), ("cook", 20), ("dinner", 15), ("deep clean", 20),
        ("bathroom", 12), ("shower", 10), ("bathtub", 10), ("toilet", 5), ("vacuum", 10), ("hoover", 10), ("mop", 10),
        ("sweep", 6), ("fold", 10), ("laundry", 5), ("dishwasher", 5), ("dishes", 10), ("trash", 4), ("garbage", 4),
        ("recycling", 4), ("bins", 4), ("make bed", 3), ("make my bed", 3), ("make the bed", 3), ("walk", 15),
        ("litter", 5), ("feed", 3), ("water", 4), ("dust", 8), ("wipe", 4), ("windows", 10), ("fridge", 10),
        ("garage", 20), ("car", 15), ("bedroom", 10), ("room", 10), ("toys", 5), ("tidy", 5), ("pick up", 5),
    ]

    private static let categories: [(String, [String])] = [
        ("kitchen", ["dish", "kitchen", "counter", "stove", "microwave", "cook", "dinner", "fridge", "oven", "pantry", "lunch"]),
        ("bathroom", ["bath", "toilet", "shower", "mirror", "sink"]),
        ("laundry", ["laundry", "clothes", "fold", "washer", "dryer", "towel", "sheets"]),
        ("floors", ["vacuum", "hoover", "sweep", "mop", "floor", "rug", "carpet", "stairs"]),
        ("outdoor", ["trash", "garbage", "recycling", "bins", "yard", "mow", "garden", "plants", "dog", "walk", "rake",
                     "snow", "shovel", "car", "garage", "weed", "mail", "porch", "patio", "lawn"]),
        ("room", ["bed", "room", "toys", "desk", "closet", "backpack", "books"]),
    ]

    // MARK: Ids

    private static func key(_ name: String) -> String {
        name.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// "take out the trash" → "take-out-the-trash", with a number on the end if that's taken.
    private static func uniqueId(for name: String, taken: Set<String>) -> String {
        let slug = name.unicodeScalars.map { scalar -> Character in
            scalar.isASCII && (CharacterSet.alphanumerics.contains(scalar)) ? Character(scalar) : "-"
        }
        let base = String(slug).split(separator: "-").joined(separator: "-")
        let root = base.isEmpty ? "chore" : base
        if !taken.contains(root) { return root }
        var n = 2
        while taken.contains("\(root)-\(n)") { n += 1 }
        return "\(root)-\(n)"
    }
}
