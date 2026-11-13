import Foundation

/// The parent gate. A lightweight "are you a grown-up?" check, the same one the
/// web app uses: the code is stored as a hash, not as plaintext. It is not a
/// security boundary.
public enum AdminGate {
    public static let codeHash: UInt32 = 1_305_456_521

    /// 32-bit FNV-1a over UTF-16 code units — identical to `hashCode` in index.html.
    public static func hash(_ string: String) -> UInt32 {
        var h: UInt32 = 2_166_136_261
        for unit in string.utf16 {
            h ^= UInt32(unit)
            h = h &* 16_777_619
        }
        return h
    }

    public static func verify(_ code: String) -> Bool {
        hash(code) == codeHash
    }
}
