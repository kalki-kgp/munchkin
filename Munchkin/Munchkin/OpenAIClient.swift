import Foundation

final class OpenAIClient: LLMClient {
    private let settings: SettingsStore
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config)
    }()

    init(settings: SettingsStore) { self.settings = settings }

    struct ChatRequest: Encodable { let model: String; let messages: [NebiusClient.Message] }
    struct ChatResponse: Decodable { let choices: [Choice]; struct Choice: Decodable { let message: NebiusClient.ChatResponse.Choice.Msg } }

    func send(prompt: String, systemPrompt: String?, completion: @escaping (Result<String, Error>) -> Void) {
        guard let apiKey = settings.apiKey(for: .openai), !apiKey.isEmpty else {
            completion(.failure(OpenAIError(message: "API key not set"))); return
        }
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        var messages: [NebiusClient.Message] = []
        if let sys = systemPrompt, !sys.isEmpty { messages.append(.init(role: "system", content: sys)) }
        messages.append(.init(role: "user", content: prompt))
        let body = ChatRequest(model: settings.model, messages: messages)
        do { req.httpBody = try JSONEncoder().encode(body) } catch { completion(.failure(error)); return }

        session.dataTask(with: req) { data, response, error in
            if let error = error { completion(.failure(error)); return }
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode), let data = data else {
                completion(.failure(OpenAIError(message: "Invalid HTTP response"))); return
            }
            do {
                let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
                if let first = decoded.choices.first?.message.content { completion(.success(first)) }
                else { completion(.failure(OpenAIError(message: "Empty response"))) }
            } catch { completion(.failure(error)) }
        }.resume()
    }

    struct ModelsResponse: Decodable { let data: [Model]; struct Model: Decodable { let id: String } }
    func listModels(completion: @escaping (Result<[String], Error>) -> Void) {
        guard let apiKey = settings.apiKey(for: .openai), !apiKey.isEmpty else {
            completion(.failure(OpenAIError(message: "API key not set"))); return
        }
        let url = URL(string: "https://api.openai.com/v1/models")!
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
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

