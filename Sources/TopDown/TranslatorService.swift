import Foundation

struct TranslationOutcome: Equatable {
    let text: String
    let reverted: Bool
    let reason: String
    let faithfulnessScore: Int
}

struct TranslatorService {
    private let client: OpenAIClient

    init(client: OpenAIClient = OpenAIClient()) {
        self.client = client
    }

    func translate(_ original: String, apiKey: String) async throws -> TranslationOutcome {
        let protected = OpaqueProtector.protect(original)
        let translation = try await client.structuredResponse(
            apiKey: apiKey,
            instructions: Prompts.translator,
            input: ["id": "message", "slack_message": protected.text],
            name: "top_down_translation",
            schema: Schemas.translation
        )

        guard let rows = translation["translations"] as? [[String: Any]],
              rows.count == 1,
              rows[0]["id"] as? String == "message",
              let candidate = rows[0]["text"] as? String else {
            return TranslationOutcome(text: original, reverted: true, reason: "Invalid rewrite", faithfulnessScore: 0)
        }

        guard (try? OpaqueProtector.restore(candidate, spans: protected.spans)) != nil else {
            return TranslationOutcome(text: original, reverted: true, reason: "A frozen span changed", faithfulnessScore: 0)
        }

        let verification = try await client.structuredResponse(
            apiKey: apiKey,
            instructions: Prompts.verifier,
            input: ["original_message": protected.text, "candidate_message": candidate],
            name: "translation_verification",
            schema: Schemas.verification
        )
        guard let score = verification["faithfulness_score"] as? Int,
              let meaningChanged = verification["meaning_changed"] as? Bool else {
            return TranslationOutcome(text: original, reverted: true, reason: "Verification failed", faithfulnessScore: 0)
        }
        guard !meaningChanged, score >= 98 else {
            return TranslationOutcome(text: original, reverted: true, reason: "Meaning check returned \(score)", faithfulnessScore: score)
        }

        let restored = try OpaqueProtector.restore(candidate, spans: protected.spans)
        return TranslationOutcome(text: restored, reverted: false, reason: "", faithfulnessScore: score)
    }
}

struct OpenAIClient {
    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpCookieStorage = nil
        session = URLSession(configuration: configuration)
    }

    func structuredResponse(
        apiKey: String,
        instructions: String,
        input: [String: String],
        name: String,
        schema: [String: Any]
    ) async throws -> [String: Any] {
        let inputData = try JSONSerialization.data(withJSONObject: input)
        let inputText = String(decoding: inputData, as: UTF8.self)
        let body: [String: Any] = [
            "model": "gpt-5.6-luna",
            "instructions": instructions,
            "input": inputText,
            "reasoning": ["effort": "low"],
            "max_output_tokens": 16_384,
            "store": false,
            "text": [
                "format": [
                    "type": "json_schema",
                    "name": name,
                    "strict": true,
                    "schema": schema,
                ],
            ],
        ]
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw TranslatorError.invalidResponse }
        let payload = try JSONDecoder().decode(ResponsePayload.self, from: data)
        guard (200..<300).contains(http.statusCode) else {
            throw TranslatorError.api(payload.error?.message ?? "OpenAI returned \(http.statusCode)")
        }
        let contents = (payload.output ?? []).flatMap { output in
            output.content ?? []
        }
        guard payload.status == "completed",
              let outputText = contents.first(where: { $0.type == "output_text" })?.text,
              let outputData = outputText.data(using: .utf8),
              let object = try JSONSerialization.jsonObject(with: outputData) as? [String: Any] else {
            throw TranslatorError.invalidResponse
        }
        return object
    }
}

private struct ResponsePayload: Decodable {
    struct Output: Decodable {
        let content: [Content]?
    }

    struct Content: Decodable {
        let type: String?
        let text: String?
    }

    struct APIError: Decodable {
        let message: String?
    }

    let status: String?
    let output: [Output]?
    let error: APIError?
}

enum TranslatorError: LocalizedError {
    case invalidResponse
    case api(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "OpenAI returned an invalid response."
        case .api(let message): message
        }
    }
}

enum Schemas {
    static let translation: [String: Any] = [
        "type": "object",
        "properties": [
            "translations": [
                "type": "array",
                "items": [
                    "type": "object",
                    "properties": [
                        "id": ["type": "string"],
                        "text": ["type": "string"],
                    ],
                    "required": ["id", "text"],
                    "additionalProperties": false,
                ],
            ],
        ],
        "required": ["translations"],
        "additionalProperties": false,
    ]

    static let verification: [String: Any] = [
        "type": "object",
        "properties": [
            "faithfulness_score": ["type": "integer", "minimum": 0, "maximum": 100],
            "meaning_changed": ["type": "boolean"],
        ],
        "required": ["faithfulness_score", "meaning_changed"],
        "additionalProperties": false,
    ]
}
