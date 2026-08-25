import Foundation

struct FrozenSpan: Equatable {
    let token: String
    let value: String
}

struct ProtectedMessage: Equatable {
    let text: String
    let spans: [FrozenSpan]
}

enum OpaqueProtector {
    static func protect(_ input: String) -> ProtectedMessage {
        let prefix = "TD_\(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(10))"
        var spans: [FrozenSpan] = []
        var text = input

        func replace(_ pattern: String, kind: String) {
            text = replacingMatches(pattern: pattern, in: text) { value in
                let token = "[[\(prefix)_\(kind)_\(spans.count + 1)]]"
                spans.append(FrozenSpan(token: token, value: value))
                return token
            }
        }

        replace(#"```[\s\S]*?```"#, kind: "CODE")
        text = protectTrailingJSON(in: text, prefix: prefix, spans: &spans)
        replace(#"“[^”]+”|"[^"\n]{2,}""#, kind: "QUOTE")
        replace(#"<[^>\n]+>"#, kind: "SLACK")
        replace(#"https?://\S+"#, kind: "URL")
        replace(#"\b(?:[A-Fa-f0-9]{32,}|[A-Za-z0-9_-]{48,})\b"#, kind: "SECRET")
        return ProtectedMessage(text: text, spans: spans)
    }

    static func restore(_ input: String, spans: [FrozenSpan]) throws -> String {
        var output = input
        for span in spans {
            guard output.components(separatedBy: span.token).count - 1 == 1 else {
                throw OpaqueProtectorError.spanMismatch
            }
            output = output.replacingOccurrences(of: span.token, with: span.value)
        }
        return output
    }

    private static func replacingMatches(
        pattern: String,
        in input: String,
        transform: (String) -> String
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return input }
        var output = input
        let matches = regex.matches(in: input, range: NSRange(input.startIndex..., in: input))
        for match in matches.reversed() {
            guard let sourceRange = Range(match.range, in: output) else { continue }
            let value = String(output[sourceRange])
            output.replaceSubrange(sourceRange, with: transform(value))
        }
        return output
    }

    private static func protectTrailingJSON(
        in input: String,
        prefix: String,
        spans: inout [FrozenSpan]
    ) -> String {
        for marker in ["{", "["] {
            guard let start = input.firstIndex(of: Character(marker)) else { continue }
            let candidate = String(input[start...]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard let data = candidate.data(using: .utf8),
                  (try? JSONSerialization.jsonObject(with: data)) != nil else { continue }
            let token = "[[\(prefix)_CODE_\(spans.count + 1)]]"
            spans.append(FrozenSpan(token: token, value: candidate))
            return String(input[..<start]) + token
        }
        return input
    }
}

enum OpaqueProtectorError: Error {
    case spanMismatch
}
