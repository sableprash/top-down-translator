import Foundation

@main
struct OpaqueProtectorSelfTest {
    static func main() throws {
        let original = #"<@U123|Prash> said "keep this" at https://example.com ```x = 1``` abcdef0123456789abcdef0123456789"#
        let protected = OpaqueProtector.protect(original)
        precondition(!protected.text.contains("example.com"))
        precondition(!protected.text.contains("abcdef0123456789"))
        let restored = try OpaqueProtector.restore(protected.text, spans: protected.spans)
        precondition(restored == original)

        let json = "I added this:\n{\"token\":\"secret\",\"enabled\":true}"
        let protectedJSON = OpaqueProtector.protect(json)
        precondition(protectedJSON.spans.count == 1)
        let restoredJSON = try OpaqueProtector.restore(protectedJSON.text, spans: protectedJSON.spans)
        precondition(restoredJSON == json)

        do {
            _ = try OpaqueProtector.restore("See", spans: OpaqueProtector.protect("See https://example.com").spans)
            preconditionFailure("Missing frozen span was accepted")
        } catch OpaqueProtectorError.spanMismatch {
            // Expected.
        }

        print("Swift self-tests passed")
    }
}
