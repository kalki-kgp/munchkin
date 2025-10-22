import Foundation

struct OpenAIError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

final class NebiusClient: LLMClient {
    private let settings: SettingsStore
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config)
    }()

    init(settings: SettingsStore) {
        self.settings = settings
    }

    struct ChatRequest: Encodable, Sendable {
        let model: String
        let messages: [Message]
    }

    struct Message: Encodable, Sendable {
        let role: String
        let content: String
    }

    struct ChatResponse: Decodable, Sendable {
        struct Choice: Decodable, Sendable {
            struct Msg: Decodable, Sendable { let role: String; let content: String }
            let message: Msg
        }
        let choices: [Choice]
    }

    func send(prompt: String, systemPrompt: String? = nil, completion: @escaping (Result<String, Error>) -> Void) {
        guard let apiKey = settings.apiKey(for: .nebius), !apiKey.isEmpty else {
            completion(.failure(OpenAIError(message: "API key not set")))
            return
        }

        // Nebius: OpenAI-compatible API
        let url = URL(string: "https://api.studio.nebius.com/v1/chat/completions")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        var messages: [Message] = []
        if let sys = systemPrompt, !sys.isEmpty {
            messages.append(.init(role: "system", content: sys))
        }
        messages.append(.init(role: "user", content: prompt))

        let body = ChatRequest(model: settings.model, messages: messages)
        do {
            req.httpBody = try JSONEncoder().encode(body)
        } catch {
            completion(.failure(error)); return
        }

        session.dataTask(with: req) { data, response, error in
            if let error = error { completion(.failure(error)); return }
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode), let data = data else {
                completion(.failure(OpenAIError(message: "Invalid HTTP response"))); return
            }
            do {
                let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
                if let first = decoded.choices.first?.message.content {
                    completion(.success(first))
                } else {
                    completion(.failure(OpenAIError(message: "Empty response")))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    // Optional: fetch available models from Nebius
    struct ModelsResponse: Decodable, Sendable { 
        let data: [Model]
        struct Model: Decodable, Sendable { let id: String }
    }
    func listModels(completion: @escaping (Result<[String], Error>) -> Void) {
        guard let apiKey = settings.apiKey(for: .nebius), !apiKey.isEmpty else {
            completion(.failure(OpenAIError(message: "API key not set")))
            return
        }
        let url = URL(string: "https://api.studio.nebius.com/v1/models")!
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        session.dataTask(with: req) { data, response, error in
            if let error = error { completion(.failure(error)); return }
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode), let data = data else {
                completion(.failure(OpenAIError(message: "Invalid HTTP response"))); return
            }
            do {
                let decoded = try JSONDecoder().decode(ModelsResponse.self, from: data)
                completion(.success(decoded.data.map { $0.id }))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}
