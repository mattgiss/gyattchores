import Foundation
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

/// The encrypted relay's keys and record format (docs/design/encrypted-relay-join.md). Android's
/// `RelayCrypto.kt` is the same, and both are checked against native/fixtures/relay-crypto.json,
/// written by native/tools/relay-crypto.mjs, which also spells out the format.
///
/// The family key never leaves the family's phones: it travels from screen to camera in the join
/// code. The server only ever sees sealed records, hashed state keys and a hash of the join token.
public struct FamilyKeys: Sendable, Equatable {
    public enum Failure: Error, Equatable { case badLength, badJoinCode, cannotOpen }

    /// 16 bytes, made on the first phone. Also the household's id on the server (as a UUID).
    public let household: Data
    /// 32 bytes. Never sent to the server.
    public let familyKey: Data

    public init(household: Data, familyKey: Data) throws {
        guard household.count == 16, familyKey.count == 32 else { throw Failure.badLength }
        self.household = household; self.familyKey = familyKey
    }

    /// A new family's keys, from the system's secure random source.
    public static func generate() -> FamilyKeys {
        try! FamilyKeys(household: RelayCrypto.random(16), familyKey: RelayCrypto.random(32))
    }

    /// The household id as the server stores it.
    public var householdUUID: UUID {
        let b = [UInt8](household)
        return UUID(uuid: (b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7], b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]))
    }

    var encKey: SymmetricKey { subkey("dyw1 enc") }
    var rowKey: SymmetricKey { subkey("dyw1 row") }

    private func subkey(_ info: String) -> SymmetricKey {
        HKDF<SHA256>.deriveKey(inputKeyMaterial: SymmetricKey(data: familyKey), salt: household, info: Data(info.utf8), outputByteCount: 32)
    }

    private func aad(kind: String, rowId: String) -> Data {
        household + Data(kind.utf8) + Data([0]) + Data(rowId.utf8)
    }

    /// Encrypts one record for the server: base64 of version 1, nonce, ciphertext and tag. The kind
    /// and row id are bound in, so the server can't move a record to another row, kind or family.
    public func seal(_ plaintext: Data, kind: String, rowId: String) throws -> String {
        try seal(plaintext, kind: kind, rowId: rowId, nonce: AES.GCM.Nonce())
    }

    func seal(_ plaintext: Data, kind: String, rowId: String, nonce: AES.GCM.Nonce) throws -> String {
        let box = try AES.GCM.seal(plaintext, using: encKey, nonce: nonce, authenticating: aad(kind: kind, rowId: rowId))
        return (Data([1]) + Data(box.nonce) + box.ciphertext + box.tag).base64EncodedString()
    }

    /// Opens a record sealed by any of the family's phones. Throws if it was altered, moved, or
    /// sealed under another family's key.
    public func open(_ sealed: String, kind: String, rowId: String) throws -> Data {
        guard let raw = Data(base64Encoded: sealed), raw.count >= 1 + 12 + 16, raw.first == 1 else { throw Failure.cannotOpen }
        let body = raw.dropFirst()
        do {
            let box = try AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: body.prefix(12)),
                                            ciphertext: body.dropFirst(12).dropLast(16), tag: body.suffix(16))
            return try AES.GCM.open(box, using: encKey, authenticating: aad(kind: kind, rowId: rowId))
        } catch { throw Failure.cannotOpen }
    }

    /// The server's row id for a piece of shared state, so names like "dare|3|2026-11-16" don't show.
    public func stateRowId(_ key: String) -> String {
        RelayCrypto.base64url(Data(HMAC<SHA256>.authenticationCode(for: Data(key.utf8), using: rowKey)))
    }
}

/// What the "Add a phone" QR code carries: the family's keys and a one-time join token.
public struct JoinCode: Sendable, Equatable {
    public static let prefix = "dyw1:"
    public let keys: FamilyKeys
    /// 32 random bytes. The server keeps only its SHA-256, for 10 minutes.
    public let token: Data

    public init(keys: FamilyKeys, token: Data) throws {
        guard token.count == 32 else { throw FamilyKeys.Failure.badLength }
        self.keys = keys; self.token = token
    }

    /// A fresh code for this family.
    public static func make(for keys: FamilyKeys) -> JoinCode { try! JoinCode(keys: keys, token: RelayCrypto.random(32)) }

    /// Reads a scanned code. Throws on anything that isn't a DOYOURWORK join code.
    public init(scanned text: String) throws {
        let s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard s.hasPrefix(Self.prefix), let raw = RelayCrypto.base64urlDecode(String(s.dropFirst(Self.prefix.count))), raw.count == 80
        else { throw FamilyKeys.Failure.badJoinCode }
        let b = [UInt8](raw)
        try self.init(keys: FamilyKeys(household: Data(b[0..<16]), familyKey: Data(b[16..<48])), token: Data(b[48..<80]))
    }

    /// The text to draw as a QR code.
    public var text: String { Self.prefix + RelayCrypto.base64url(keys.household + keys.familyKey + token) }

    /// What the first phone sends the server when it shows this code.
    public var tokenHash: Data { Data(SHA256.hash(data: token)) }
}

public enum RelayCrypto {
    static func random(_ n: Int) -> Data {
        // SymmetricKey draws from the system's secure random source on every platform.
        SymmetricKey(size: SymmetricKeySize(bitCount: n * 8)).withUnsafeBytes { Data($0) }
    }

    static func base64url(_ d: Data) -> String {
        d.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func base64urlDecode(_ s: String) -> Data? {
        guard s.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }) else { return nil }
        var b = s.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        b += String(repeating: "=", count: (4 - b.count % 4) % 4)
        return Data(base64Encoded: b)
    }
}
