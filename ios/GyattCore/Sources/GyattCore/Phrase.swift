import Foundation

/// Plain-English sentences about chores, so the app talks like a person: "Sam emptied the kids
/// bathroom trash today." Chore names are written as instructions ("empty kids bathroom trash"),
/// so the first word is put in the past tense. The same rules as Android's Phrase.kt.
public enum Phrase {
    private static let irregular: [String: String] = [
        "bring": "brought", "buy": "bought", "do": "did", "feed": "fed", "get": "got", "give": "gave",
        "go": "went", "hang": "hung", "lay": "laid", "leave": "left", "make": "made", "put": "put",
        "read": "read", "ride": "rode", "run": "ran", "set": "set", "shut": "shut", "sweep": "swept",
        "take": "took", "throw": "threw", "write": "wrote", "sit": "sat", "spin": "spun", "hide": "hid",
        "beat": "beat", "sell": "sold", "tell": "told", "find": "found", "hold": "held", "keep": "kept",
        "cut": "cut", "shake": "shook", "wring": "wrung", "split": "split", "spread": "spread",
    ]
    /// Short verbs that double their last letter: scrub → scrubbed.
    private static let doubles: Set<String> = ["scrub", "mop", "wrap", "chop", "prep", "drop", "plan", "stir", "pat", "rub", "tap", "trim", "stop", "dip", "plug", "pop", "tug", "hug", "jog"]
    /// Words that start a chore name but aren't something you do ("dishes", "trash out").
    private static let notVerbs: Set<String> = ["the", "a", "an", "my", "your", "all", "dishes", "laundry", "trash", "bed", "room", "homework"]
    /// Words after which "the" would read wrong: "feed the fish", "take out the trash", "fold and put away".
    private static let noArticleAfter: Set<String> = ["out", "up", "down", "off", "away", "in", "on", "over", "around", "the", "a", "an", "my", "your",
                                                      "his", "her", "their", "our", "all", "some", "every", "and", "or", "with", "to", "for", "at", "from", "into", "of"]

    /// "empty" → "emptied", "sweep" → "swept", "wipe" → "wiped", "scrub" → "scrubbed".
    public static func past(_ verb: String) -> String {
        let v = verb.lowercased()
        let out: String
        if let irr = irregular[v] { out = irr }
        else if doubles.contains(v) { out = v + String(v.last!) + "ed" }
        else if v.hasSuffix("e") { out = v + "d" }
        else if v.count > 1, v.hasSuffix("y"), !"aeiou".contains(v[v.index(v.endIndex, offsetBy: -2)]) { out = String(v.dropLast()) + "ied" }
        else { out = v + "ed" }
        return verb.first?.isUppercase == true ? out.prefix(1).uppercased() + out.dropFirst() : out
    }

    /// What someone did, as the second half of a sentence: "emptied the kids bathroom trash". A name
    /// that doesn't start with a verb is said as it is: "did dishes".
    public static func did(_ chore: String) -> String {
        let trimmed = chore.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
        guard let first = words.first else { return "did a chore" }
        if notVerbs.contains(first.lowercased()) || !first.allSatisfy({ $0.isLetter || $0 == "'" }) { return "did \(trimmed)" }
        let rest = Array(words.dropFirst())
        let article = !rest.isEmpty && !noArticleAfter.contains(rest[0].lowercased()) && !(rest[0].first?.isNumber ?? false)
        return ([past(first)] + (article ? ["the"] : []) + rest).joined(separator: " ")
    }

    /// "today", "yesterday", "on Thursday" within the week, else "on Nov 12".
    public static func when(_ day: Date, today: Date, calendar: Calendar) -> String {
        let d = calendar.startOfDay(for: day), t = calendar.startOfDay(for: today)
        let days = calendar.dateComponents([.day], from: d, to: t).day ?? 0
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US"); f.calendar = calendar; f.timeZone = calendar.timeZone
        switch days {
        case 0: return "today"
        case 1: return "yesterday"
        case 2..<7: f.dateFormat = "EEEE"; return "on " + f.string(from: d)
        default: f.dateFormat = "MMM d"; return "on " + f.string(from: d)
        }
    }

    /// "Sam emptied the kids bathroom trash today."
    public static func sentence(_ name: String, _ chore: String, on day: Date, today: Date, calendar: Calendar) -> String {
        // A sentence starts with a capital, even when someone's username doesn't.
        "\(name.prefix(1).uppercased() + name.dropFirst()) \(did(chore)) \(when(day, today: today, calendar: calendar))."
    }

    /// "1 chore", "3 chores"; "1 minute", "25 minutes".
    public static func count(_ n: Int, _ word: String) -> String { "\(n) \(word)\(n == 1 ? "" : "s")" }
}
