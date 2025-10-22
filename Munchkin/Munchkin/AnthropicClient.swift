import Foundation

final class AnthropicClient: LLMClient {
    private let settings: SettingsStore
    private let session: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 30
        c.timeoutIntervalForResource = 60
        return URLSession(configuration: c)
    }()

    init(settings: SettingsStore) { self.settings = settings }

    struct MessageBlock: Encodable { let role: String; let content: String }
    struct MsgRequest: Encodable {
        let model: String
        let max_tokens: Int
        let temperature: Double?
        let messages: [MessageBlock]
        init(model: String, messages: [MessageBlock]) {
            self.model = model
            self.max_tokens = 1024
            self.temperature = 0.3
            self.messages = messages
        }
    }
    struct MsgResponse: Decodable {
        struct Content: Decodable { let text: String? }
        let content: [Content]
    }

    func send(prompt: String, systemPrompt: String?, completion: @escaping (Result<String, Error>) -> Void) {
        guard let apiKey = settings.apiKey(for: .anthropic), !apiKey.isEmpty else {
            completion(.failure(OpenAIError(message: "API key not set"))); return
        }
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        var msgs: [MessageBlock] = []
        if let sys = systemPrompt, !sys.isEmpty { msgs.append(.init(role: "system", content: sys)) }
        msgs.append(.init(role: "user", content: prompt))
        let body = MsgRequest(model: settings.model, messages: msgs)
        do { req.httpBody = try JSONEncoder().encode(body) } catch { completion(.failure(error)); return }

        session.dataTask(with: req) { data, response, error in
            if let error = error { completion(.failure(error)); return }
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode), let data = data else {
                completion(.failure(OpenAIError(message: "Invalid HTTP response"))); return
            }
            do {
                let decoded = try JSONDecoder().decode(MsgResponse.self, from: data)
                if let t = decoded.content.first?.text, !t.isEmpty { completion(.success(t)) }
                else { completion(.failure(OpenAIError(message: "Empty response"))) }
            } catch { completion(.failure(error)) }
        }.resume()
    }

    // Anthropic models endpoint
    struct ModelsResponse: Decodable { let data: [Model]; struct Model: Decodable { let id: String } }
    func listModels(completion: @escaping (Result<[String], Error>) -> Void) {
        guard let apiKey = settings.apiKey(for: .anthropic), !apiKey.isEmpty else {
            completion(.failure(OpenAIError(message: "API key not set"))); return
        }
        // Not all Anthropic accounts list models via API; provide a seeded list on failure.
        let url = URL(string: "https://api.anthropic.com/v1/models")!
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        session.dataTask(with: req) { data, response, error in
            if let error = error { completion(.failure(error)); return }
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode), let data = data else {
                completion(.failure(OpenAIError(message: "Invalid HTTP response"))); return
            }
            do { let decoded = try JSONDecoder().decode(ModelsResponse.self, from: data); completion(.success(decoded.data.map { $0.id })) }
            catch { completion(.failure(error)) }
        }.resume()
    }
}

