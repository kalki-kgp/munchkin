import Foundation

final class SettingsStore {
    static let shared = SettingsStore()

    // Default models (seed list)
    static let defaultModels: [String] = [
        "deepseek-ai/DeepSeek-V3-0324-fast",
        "meta-llama/Llama-3.1-8B-Instruct",
        "mistralai/Mixtral-8x7B-Instruct-v0.1"
    ]

    private let defaults = UserDefaults.standard
    private let keychain = KeychainStore(service: "dev.munchkin")

    // UserDefaults-backed
    private let kIsActive = "isActive"
    private let kModel = "model"
    private let kQuietSeconds = "quietSeconds"
    private let kDelimiter = "delimiter"
    private let kMaxChars = "maxChars"
    private let kAvailableModels = "availableModels"
    private let kProvider = "provider"
    private let kSystemPrompt = "systemPrompt"
    private let kUseSystemPrompt = "useSystemPrompt"
    private let kStealthMode = "stealthMode"
    private let kShowTime = "showTimeInMenubar"
    private let kShowIcon = "showStatusIcon"
    private let kIgnoreShortLen = "ignoreShortCopyBelow"
    private let kRedactEmails = "redactEmails"
    private let kRedactURLs = "redactURLs"
    private let kRedactNumbers = "redactNumbers"
    private let kOverlayAutoShow = "overlayAutoShow"
    private let kOverlayPlacement = "overlayPlacement"
    private let kOverlayWidth = "overlayWidth"
    private let kOverlayFontSize = "overlayFontSize"
    private let kOverlayAutoHide = "overlayAutoHideSeconds"
    private let kOverlayExcludeShare = "overlayExcludeShare"
    private let kOverlayTextColor = "overlayTextColor"
    private let kOverlayScrollSensitivity = "overlayScrollSensitivity"

    // Keychain-backed
    private let kAPIKey = "nebius_api_key"

    var isActive: Bool {
        get { defaults.object(forKey: kIsActive) as? Bool ?? true }
        set { defaults.set(newValue, forKey: kIsActive) }
    }

    var model: String {
        get {
            defaults.string(forKey: kModel) ?? availableModels.first ?? SettingsStore.defaultModels.first!
        }
        set { defaults.set(newValue, forKey: kModel) }
    }

    var quietSeconds: TimeInterval {
        get { defaults.object(forKey: kQuietSeconds) as? TimeInterval ?? 5.0 }
        set { defaults.set(newValue, forKey: kQuietSeconds) }
    }

    var delimiter: String {
        get { defaults.string(forKey: kDelimiter) ?? "\n\n" }
        set { defaults.set(newValue, forKey: kDelimiter) }
    }

    var maxChars: Int {
        get { defaults.object(forKey: kMaxChars) as? Int ?? 12000 }
        set { defaults.set(newValue, forKey: kMaxChars) }
    }

    // Provider selection
    var provider: ModelProvider {
        get { ModelProvider(rawValue: defaults.string(forKey: kProvider) ?? ModelProvider.nebius.rawValue) ?? .nebius }
        set {
            defaults.set(newValue.rawValue, forKey: kProvider)
            // Reset models to defaults for new provider
            availableModels = SettingsStore.defaultModels(for: newValue)
        }
    }

    // Per-provider API key management
    func apiKey(for provider: ModelProvider) -> String? {
        switch provider {
        case .nebius: return keychain.read(key: "nebius_api_key")
        case .openai: return keychain.read(key: "openai_api_key")
        case .anthropic: return keychain.read(key: "anthropic_api_key")
        case .groq: return keychain.read(key: "groq_api_key")
        }
    }
    func setApiKey(_ key: String?, for provider: ModelProvider) {
        let val = (key ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let k: String
        switch provider {
        case .nebius: k = "nebius_api_key"
        case .openai: k = "openai_api_key"
        case .anthropic: k = "anthropic_api_key"
        case .groq: k = "groq_api_key"
        }
        if val.isEmpty { keychain.delete(key: k) } else { keychain.save(key: k, value: val) }
    }

    // Dynamic list of available models loaded from Nebius
    var availableModels: [String] {
        get {
            if let arr = defaults.array(forKey: kAvailableModels) as? [String], !arr.isEmpty {
                return arr
            }
            return SettingsStore.defaultModels(for: provider)
        }
        set {
            defaults.set(newValue, forKey: kAvailableModels)
            // Ensure current model remains valid
            if !newValue.contains(model), let first = newValue.first {
                model = first
            }
        }
    }

    // Optional system prompt sent with every request
    var systemPrompt: String {
        get { defaults.string(forKey: kSystemPrompt) ?? "" }
        set { defaults.set(newValue, forKey: kSystemPrompt) }
    }

    var useSystemPrompt: Bool {
        get { defaults.object(forKey: kUseSystemPrompt) as? Bool ?? true }
        set { defaults.set(newValue, forKey: kUseSystemPrompt) }
    }

    var stealthMode: Bool {
        get { defaults.object(forKey: kStealthMode) as? Bool ?? false }
        set { defaults.set(newValue, forKey: kStealthMode) }
    }

    var showTimeInMenubar: Bool {
        get { defaults.object(forKey: kShowTime) as? Bool ?? true }
        set { defaults.set(newValue, forKey: kShowTime) }
    }

    var showStatusIcon: Bool {
        get { defaults.object(forKey: kShowIcon) as? Bool ?? true }
        set { defaults.set(newValue, forKey: kShowIcon) }
    }

    var ignoreShortCopyBelow: Int {
        get { defaults.object(forKey: kIgnoreShortLen) as? Int ?? 3 }
        set { defaults.set(newValue, forKey: kIgnoreShortLen) }
    }

    var redactEmails: Bool {
        get { defaults.object(forKey: kRedactEmails) as? Bool ?? false }
        set { defaults.set(newValue, forKey: kRedactEmails) }
    }

    var redactURLs: Bool {
        get { defaults.object(forKey: kRedactURLs) as? Bool ?? false }
        set { defaults.set(newValue, forKey: kRedactURLs) }
    }

    var redactNumbers: Bool {
        get { defaults.object(forKey: kRedactNumbers) as? Bool ?? false }
        set { defaults.set(newValue, forKey: kRedactNumbers) }
    }

    // Overlay settings
    var overlayAutoShow: Bool {
        get { defaults.object(forKey: kOverlayAutoShow) as? Bool ?? true }
        set { defaults.set(newValue, forKey: kOverlayAutoShow) }
    }
    var overlayPlacement: OverlayPlacement {
        get { OverlayPlacement(rawValue: defaults.string(forKey: kOverlayPlacement) ?? OverlayPlacement.cursor.rawValue) ?? .cursor }
        set { defaults.set(newValue.rawValue, forKey: kOverlayPlacement) }
    }
    var overlayWidth: Int {
        get { defaults.object(forKey: kOverlayWidth) as? Int ?? 420 }
        set { defaults.set(newValue, forKey: kOverlayWidth) }
    }
    var overlayFontSize: Double {
        get { defaults.object(forKey: kOverlayFontSize) as? Double ?? 14 }
        set { defaults.set(newValue, forKey: kOverlayFontSize) }
    }
    var overlayAutoHideSeconds: TimeInterval {
        get { (defaults.object(forKey: kOverlayAutoHide) as? Double) ?? 600 }
        set { defaults.set(newValue, forKey: kOverlayAutoHide) }
    }
    var overlayExcludeFromScreenShare: Bool {
        get { defaults.object(forKey: kOverlayExcludeShare) as? Bool ?? true }
        set { defaults.set(newValue, forKey: kOverlayExcludeShare) }
    }

    var overlayTextColor: String {
        get { defaults.string(forKey: kOverlayTextColor) ?? "black" }
        set { defaults.set(newValue, forKey: kOverlayTextColor) }
    }

    // The delta threshold to advance one line on scroll (higher = less sensitive)
    var overlayScrollSensitivity: Double {
        get { defaults.object(forKey: kOverlayScrollSensitivity) as? Double ?? 30 }
        set { defaults.set(newValue, forKey: kOverlayScrollSensitivity) }
    }

    // Default models per provider
    static func defaultModels(for provider: ModelProvider) -> [String] {
        switch provider {
        case .nebius:
            return [
                "deepseek-ai/DeepSeek-V3-0324-fast",
                "meta-llama/Llama-3.1-8B-Instruct",
                "mistralai/Mixtral-8x7B-Instruct-v0.1"
            ]
        case .openai:
            return [
                "gpt-4o-mini",
                "gpt-4.1-mini",
                "o3-mini"
            ]
        case .anthropic:
            return [
                "claude-3-haiku-20240307",
                "claude-3-sonnet-20240229",
                "claude-3-opus-20240229"
            ]
        case .groq:
            return [
                "llama-3.1-70b-versatile",
                "mixtral-8x7b-32768",
                "gemma2-9b-it"
            ]
        }
    }
}
