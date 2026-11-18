import XCTest
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif
@testable import DoYourWorkCore

/// The relay's bytes must match native/fixtures/relay-crypto.json exactly, as Android's must, so an
/// iPhone and an Android phone can open each other's records.
final class RelayCryptoTests: XCTestCase {
    struct Vectors: Decodable {
        struct Seal: Decodable { let kind: String, rowId: String, nonce: String, plaintext: String, sealed: String }
        struct Row: Decodable { let key: String, rowId: String }
        struct Join: Decodable { let token: String, code: String, tokenHash: String }
        let familyKey: String, household: String, encKey: String, rowKey: String
        let seal: [Seal], stateRowIds: [Row], joinCode: Join
    }

    static let v: Vectors = try! JSONDecoder().decode(Vectors.self, from: Data(contentsOf:
        EngineTests.repo.appendingPathComponent("native/fixtures/relay-crypto.json")))
    var v: Vectors { Self.v }
    var keys: FamilyKeys { try! FamilyKeys(household: hex(v.household), familyKey: hex(v.familyKey)) }

    func hex(_ s: String) -> Data {
        Data(stride(from: 0, to: s.count, by: 2).map { UInt8(s.dropFirst($0).prefix(2), radix: 16)! })
    }
    func hexString(_ d: Data) -> String { d.map { String(format: "%02x", $0) }.joined() }

    func testSubkeysMatch() {
        XCTAssertEqual(keys.encKey.withUnsafeBytes { hexString(Data($0)) }, v.encKey)
        XCTAssertEqual(keys.rowKey.withUnsafeBytes { hexString(Data($0)) }, v.rowKey)
    }

    func testSealsTheSameBytesAndOpensThem() throws {
        for c in v.seal {
            let sealed = try keys.seal(Data(c.plaintext.utf8), kind: c.kind, rowId: c.rowId, nonce: AES.GCM.Nonce(data: hex(c.nonce)))
            XCTAssertEqual(sealed, c.sealed, c.rowId)
            XCTAssertEqual(String(decoding: try keys.open(c.sealed, kind: c.kind, rowId: c.rowId), as: UTF8.self), c.plaintext)
        }
    }

    func testRefusesMovedOrAlteredRecords() throws {
        let c = v.seal[0]
        XCTAssertThrowsError(try keys.open(c.sealed, kind: "state", rowId: c.rowId), "another kind")
        XCTAssertThrowsError(try keys.open(c.sealed, kind: c.kind, rowId: c.rowId + "x"), "another row")
        var raw = Data(base64Encoded: c.sealed)!; raw[raw.count - 1] ^= 1
        XCTAssertThrowsError(try keys.open(raw.base64EncodedString(), kind: c.kind, rowId: c.rowId), "a flipped bit")
        let other = FamilyKeys.generate()
        XCTAssertThrowsError(try other.open(c.sealed, kind: c.kind, rowId: c.rowId), "another family")
        XCTAssertThrowsError(try keys.open("not base64!", kind: c.kind, rowId: c.rowId))
        XCTAssertThrowsError(try keys.open("AQ==", kind: c.kind, rowId: c.rowId), "too short")
    }

    func testFreshNoncesEachTime() throws {
        let a = try keys.seal(Data("x".utf8), kind: "log", rowId: "r"), b = try keys.seal(Data("x".utf8), kind: "log", rowId: "r")
        XCTAssertNotEqual(a, b)
        XCTAssertEqual(try keys.open(a, kind: "log", rowId: "r"), Data("x".utf8))
    }

    func testStateRowIds() {
        for r in v.stateRowIds { XCTAssertEqual(keys.stateRowId(r.key), r.rowId, r.key) }
    }

    func testJoinCode() throws {
        let code = try JoinCode(keys: keys, token: hex(v.joinCode.token))
        XCTAssertEqual(code.text, v.joinCode.code)
        XCTAssertEqual(hexString(code.tokenHash), v.joinCode.tokenHash)
        XCTAssertEqual(try JoinCode(scanned: " \(v.joinCode.code)\n"), code)
        for bad in ["", "dyw1:", "dyw2:" + v.joinCode.code.dropFirst(5), String(v.joinCode.code.dropLast()), v.joinCode.code + "AA",
                    "https://example.com", v.joinCode.code.replacingOccurrences(of: "o", with: "+")] {
            XCTAssertThrowsError(try JoinCode(scanned: bad), bad)
        }
        let fresh = JoinCode.make(for: FamilyKeys.generate())
        XCTAssertEqual(try JoinCode(scanned: fresh.text), fresh)
    }

    /// The log in the fixture is the JSON both apps put inside a sealed record; each must read it.
    func testReadsTheSharedLogPayload() throws {
        let p = try JSONDecoder().decode(RelayClient.LogPayload.self, from: Data(v.seal[0].plaintext.utf8))
        XCTAssertEqual(p.id, v.seal[0].rowId); XCTAssertEqual(p.minutes, 5); XCTAssertEqual(p.timestamp, 1_731_700_000_000)
        let noMinutes = try JSONDecoder().decode(RelayClient.LogPayload.self, from: Data(#"{"id":"a","playerId":"1","playerName":"k","choreId":"c","choreName":"c","points":1,"status":"pending","timestamp":1,"later":"ignored"}"#.utf8))
        XCTAssertNil(noMinutes.minutes)
    }

    func testHouseholdUUID() {
        XCTAssertEqual(keys.householdUUID.uuidString.lowercased(), "a1b2c3d4-e5f6-0718-293a-4b5c6d7e8f90")
    }
}
