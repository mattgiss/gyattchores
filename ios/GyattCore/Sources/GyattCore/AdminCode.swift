import Foundation

/// An admin's code, kept as a salted hash so the code itself is never written down.
///
/// The hash is the same small one the admin gate has always used. That's a deliberate choice, not
/// an oversight: a code is a few digits, so any hash of it can be tried exhaustively in a moment.
/// What keeps it from a curious player is that the file lives in the app's own storage on the
/// device, which other apps and people using the phone can't read. The salt only makes sure two
/// admins with the same code don't end up with matching entries.
public struct AdminCode: Codable, Hashable, Sendable {
    public static let minLength = 4

    public let salt: String
    public let hash: UInt32

    /// Nil if the code is too short. Spaces around it are ignored, since they're invisible when typed.
    public init?(_ code: String, salt: String = UUID().uuidString) {
        let trimmed = Self.tidy(code)
        guard trimmed.count >= Self.minLength else { return nil }
        self.salt = salt
        self.hash = Engine.fnv1a(salt + trimmed)
    }

    public func matches(_ code: String) -> Bool {
        Engine.fnv1a(salt + Self.tidy(code)) == hash
    }

    public static func isLongEnough(_ code: String) -> Bool { tidy(code).count >= minLength }

    private static func tidy(_ code: String) -> String { code.trimmingCharacters(in: .whitespacesAndNewlines) }
}
