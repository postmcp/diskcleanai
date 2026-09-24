import Foundation

struct OpenRouterModel: Identifiable, Hashable, Decodable {
    struct Pricing: Hashable, Decodable {
        let prompt: String?
        let completion: String?
    }

    let id: String
    let name: String?
    let contextLength: Int?
    let pricing: Pricing?

    enum CodingKeys: String, CodingKey {
        case id, name, pricing
        case contextLength = "context_length"
    }

    var displayName: String { name ?? id }

    /// USD per million prompt tokens, when known.
    var promptPricePerMillion: Double? {
        guard let p = pricing?.prompt, let v = Double(p) else { return nil }
        return v * 1_000_000
    }

    var completionPricePerMillion: Double? {
        guard let p = pricing?.completion, let v = Double(p) else { return nil }
        return v * 1_000_000
    }
}

struct OpenRouterKeyInfo: Decodable {
    let label: String?
    let usage: Double?
    let limit: Double?
    let isFreeTier: Bool?

    enum CodingKeys: String, CodingKey {
        case label, usage, limit
        case isFreeTier = "is_free_tier"
    }
}

struct ChatUsage: Decodable, Hashable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int?
    let cost: Double?

    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
        case cost
    }
}

enum OpenRouterError: LocalizedError {
    case missingKey
    case http(Int, String)
    case emptyResponse
    case truncated
    case invalidJSON(String)

    var errorDescription: String? {
        switch self {
        case .missingKey: return "Add an OpenRouter API key in Settings → AI first."
        case .http(401, _): return "OpenRouter rejected the API key. Check or replace it in Settings → AI."
        case .http(402, let message): return "Your OpenRouter account is out of credits. Add credits at openrouter.ai/credits or pick a cheaper model. (\(message))"
        case .http(403, let message): return "OpenRouter refused the request: \(message)"
        case .http(429, let message): return "The model is rate-limited right now (free models are limited heavily). Wait a minute or pick another model. (\(message))"
        case .http(let code, let message) where code == 408 || code >= 500: return "The model's provider is unavailable or timed out (HTTP \(code)). Try again or pick another model. (\(message))"
        case .http(let code, let message): return "OpenRouter returned HTTP \(code). \(message)"
        case .emptyResponse: return "The model returned an empty response. Try again or pick another model."
        case .truncated: return "The model ran out of output tokens before finishing its answer (reasoning models can spend them all thinking). Try again or pick another model."
        case .invalidJSON(let text): return "The model did not return valid JSON: \(text.prefix(200))"
        }
    }

    /// Worth one automatic retry: the provider hiccuped rather than rejecting us.
    var isTransient: Bool {
        if case .http(let code, _) = self { return code == 408 || code == 502 || code == 503 || code == 504 }
        return false
    }
}

/// Thin client for the OpenRouter HTTP API. All requests carry the app's
/// referer/title headers as OpenRouter recommends for attribution.
struct OpenRouterClient {
    static let baseURL = URL(string: "https://openrouter.ai/api/v1")!

    let apiKey: String

    private func request(_ path: String, method: String = "GET", body: Data? = nil, timeout: TimeInterval = 60) -> URLRequest {
        var req = URLRequest(url: Self.baseURL.appendingPathComponent(path))
        req.httpMethod = method
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("https://diskcleanai.com", forHTTPHeaderField: "HTTP-Referer")
        req.setValue("Disk Clean AI", forHTTPHeaderField: "X-Title")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        req.timeoutInterval = timeout
        return req
    }

    private func send(_ req: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw OpenRouterError.emptyResponse }
        guard (200..<300).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            let message = (try? JSONDecoder().decode(ErrorEnvelope.self, from: data))?.error.detail ?? text
            throw OpenRouterError.http(http.statusCode, message)
        }
        return data
    }

    func verifyKey() async throws -> OpenRouterKeyInfo {
        struct Envelope: Decodable { let data: OpenRouterKeyInfo }
        let data = try await send(request("auth/key"))
        return try JSONDecoder().decode(Envelope.self, from: data).data
    }

    func listModels() async throws -> [OpenRouterModel] {
        struct Envelope: Decodable { let data: [OpenRouterModel] }
        let data = try await send(request("models"))
        return try JSONDecoder().decode(Envelope.self, from: data).data
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    struct Completion {
        let content: String
        let usage: ChatUsage?
    }

    /// Asks for JSON mode when `jsonMode` is set. Some providers reject `response_format`
    /// outright (HTTP 400), so that case is retried once without it — the prompt still asks
    /// for JSON and `AIAdvisor.parse` tolerates fences and prose around the object.
    /// Transient provider failures (408/502/503/504) are retried once after a short pause.
    func complete(model: String, system: String, user: String, temperature: Double = 0.2, jsonMode: Bool = true) async throws -> Completion {
        do {
            return try await completeOnce(model: model, system: system, user: user, temperature: temperature, jsonMode: jsonMode)
        } catch let error as OpenRouterError {
            if jsonMode, case .http(400, let message) = error, !message.localizedCaseInsensitiveContains("not a valid model") {
                return try await completeOnce(model: model, system: system, user: user, temperature: temperature, jsonMode: false)
            }
            guard error.isTransient else { throw error }
            try await Task.sleep(for: .seconds(2))
            return try await completeOnce(model: model, system: system, user: user, temperature: temperature, jsonMode: jsonMode)
        }
    }

    private func completeOnce(model: String, system: String, user: String, temperature: Double, jsonMode: Bool) async throws -> Completion {
        var payload: [String: Any] = [
            "model": model,
            "temperature": temperature,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user],
            ],
            "usage": ["include": true],
        ]
        if jsonMode { payload["response_format"] = ["type": "json_object"] }
        let body = try JSONSerialization.data(withJSONObject: payload)
        // Reasoning models can think for a minute or more before the first byte arrives.
        let data = try await send(request("chat/completions", method: "POST", body: body, timeout: 300))
        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        // OpenRouter can answer 200 and still report a provider failure in the body.
        if let error = decoded.error { throw OpenRouterError.http(error.code ?? 502, error.detail) }
        guard let choice = decoded.choices?.first else { throw OpenRouterError.emptyResponse }
        if let error = choice.error { throw OpenRouterError.http(error.code ?? 502, error.detail) }
        guard let content = choice.message?.content, !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw choice.finishReason == "length" ? OpenRouterError.truncated : OpenRouterError.emptyResponse
        }
        return Completion(content: content, usage: decoded.usage)
    }

    private struct ChatResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable { let content: String? }
            let message: Message?
            let finishReason: String?
            let error: APIError?

            enum CodingKeys: String, CodingKey {
                case message, error
                case finishReason = "finish_reason"
            }
        }
        let choices: [Choice]?
        let usage: ChatUsage?
        let error: APIError?
    }

    private struct APIError: Decodable {
        struct Metadata: Decodable {
            let raw: String?
            let providerName: String?

            enum CodingKeys: String, CodingKey {
                case raw
                case providerName = "provider_name"
            }
        }
        let message: String
        let code: Int?
        let metadata: Metadata?

        enum CodingKeys: String, CodingKey { case message, code, metadata }

        // Providers are inconsistent: `code` may be a number, a numeric string or a word.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            message = (try? c.decode(String.self, forKey: .message)) ?? "Unknown error"
            code = (try? c.decode(Int.self, forKey: .code)) ?? (try? c.decode(String.self, forKey: .code)).flatMap(Int.init)
            metadata = try? c.decode(Metadata.self, forKey: .metadata)
        }

        /// "Provider returned error" on its own tells the user nothing; the provider's
        /// own message lives in `metadata.raw`, often as a JSON string.
        var detail: String {
            guard let raw = metadata?.raw, !raw.isEmpty else { return message }
            let inner = raw.data(using: .utf8).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            let providerMessage = (inner?["message"] as? String)
                ?? ((inner?["error"] as? [String: Any])?["message"] as? String)
                ?? (inner?["error"] as? String)
                ?? String(raw.prefix(300))
            let provider = metadata?.providerName.map { "\($0): " } ?? ""
            return "\(message) — \(provider)\(providerMessage)"
        }
    }

    private struct ErrorEnvelope: Decodable {
        let error: APIError
    }
}
