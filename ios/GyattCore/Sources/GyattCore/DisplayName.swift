import Foundation

/// A nickname a player can show in place of their username. It is display only: the username and
/// the id behind it are what logs, sync and scoring use, and a display name never touches them.
public enum DisplayName {
    /// Longest display name, in characters as a person counts them (an emoji is one).
    public static let maxLength = 24
    /// Accents stacked on one character beyond this are dropped, so "zalgo" text can't spill
    /// over the rows above and below it.
    static let maxMarksPerCharacter = 2

    /// Tidies whatever was typed into something safe to show on one line: any letters, symbols and
    /// emoji are welcome; line breaks and runs of spaces become one space; invisible control and
    /// text-direction characters are removed; stacked accents and length are capped.
    /// Returns nil when nothing visible is left, meaning "use the username".
    public static func clean(_ raw: String) -> String? {
        var out = String.UnicodeScalarView()
        var count = 0
        var needsSpace = false
        for character in raw {
            if count >= maxLength { break }
            if character.unicodeScalars.allSatisfy({ $0.properties.isWhitespace }) {
                needsSpace = count > 0
                continue
            }
            var kept: [Unicode.Scalar] = []
            var marks = 0
            for scalar in character.unicodeScalars {
                switch scalar.properties.generalCategory {
                case .control, .surrogate, .privateUse, .unassigned, .lineSeparator, .paragraphSeparator:
                    continue
                case .format:
                    // Invisible formatting, including the overrides that flip text direction. The one
                    // exception joins emoji into a single picture (a family, a flag-bearer).
                    if scalar.value == 0x200D { kept.append(scalar) }
                case .nonspacingMark, .enclosingMark, .spacingMark:
                    // Variation selectors choose emoji vs text style; they aren't accents.
                    if (0xFE00...0xFE0F).contains(scalar.value) { kept.append(scalar); continue }
                    marks += 1
                    if marks <= maxMarksPerCharacter { kept.append(scalar) }
                default:
                    kept.append(scalar)
                }
            }
            // Nothing visible survived (it was all invisible formatting, or joiners with nothing to join).
            guard kept.contains(where: { $0.value != 0x200D && !(0xFE00...0xFE0F).contains($0.value) }) else { continue }
            if needsSpace, count + 1 < maxLength {
                out.append(" ")
                count += 1
            }
            needsSpace = false
            out.append(contentsOf: kept)
            count += 1
        }
        return out.isEmpty ? nil : String(out)
    }
}
