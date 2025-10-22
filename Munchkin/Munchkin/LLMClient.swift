import Foundation

protocol LLMClient {
    func send(prompt: String, systemPrompt: String?, completion: @escaping (Result<String, Error>) -> Void)
    func listModels(completion: @escaping (Result<[String], Error>) -> Void)
}

enum ModelProvider: String, CaseIterable {
    case nebius = "Nebius"
    case openai = "OpenAI"
    case anthropic = "Anthropic"
    case groq = "Groq"
}

