import SwiftUI

struct GlassBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.white.opacity(0.15), lineWidth: 1)
            )
    }
}

struct ModernSettingsView: View {
    @StateObject private var vm = SettingsVM()

    var body: some View {
        HStack(spacing: 16) {
            sidebar
            Divider().opacity(0.2)
            content
        }
        .padding(16)
        .background(
            LinearGradient(gradient: Gradient(colors: [Color.black.opacity(0.35), Color.blue.opacity(0.25)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                .overlay(.ultraThinMaterial)
        )
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Munchkin")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.primary)
            Label("General", systemImage: "gearshape")
                .settingTag(.general, selection: $vm.page)
            Label("Providers", systemImage: "rectangle.3.group.bubble.left")
                .settingTag(.providers, selection: $vm.page)
            Label("Prompt", systemImage: "text.quote")
                .settingTag(.prompt, selection: $vm.page)
            Label("Clipboard", systemImage: "doc.on.clipboard")
                .settingTag(.clipboard, selection: $vm.page)
            Label("Advanced", systemImage: "wrench.and.screwdriver")
                .settingTag(.advanced, selection: $vm.page)
            Spacer()
        }
        .padding(16)
        .frame(width: 200)
        .modifier(GlassBackground())
    }

    private var content: some View {
        Group {
            switch vm.page {
            case .general: GeneralView(vm: vm)
            case .providers: ProvidersView(vm: vm)
            case .prompt: PromptView(vm: vm)
            case .clipboard: ClipboardView(vm: vm)
            case .advanced: AdvancedView(vm: vm)
            }
        }
        .frame(minWidth: 440, maxWidth: .infinity, maxHeight: .infinity)
        .modifier(GlassBackground())
    }
}

fileprivate enum SettingsPage { case general, providers, prompt, clipboard, advanced }

final class SettingsVM: ObservableObject {
    @Published var page: SettingsPage = .general
    let s = SettingsStore.shared
}

// MARK: - Sections

private struct GeneralView: View {
    @ObservedObject var vm: SettingsVM
    @StateObject private var loginMgr = LaunchAtLoginManager.shared
    @State private var showError: String?
    var body: some View {
        Form {
            Toggle("Active", isOn: Binding(get: { vm.s.isActive }, set: { vm.s.isActive = $0 }))
            Toggle("Stealth Mode", isOn: Binding(get: { vm.s.stealthMode }, set: { vm.s.stealthMode = $0 }))
            Toggle("Show time in menubar", isOn: Binding(get: { vm.s.showTimeInMenubar }, set: { vm.s.showTimeInMenubar = $0 }))
            Toggle("Show status icon", isOn: Binding(get: { vm.s.showStatusIcon }, set: { vm.s.showStatusIcon = $0 }))
            Toggle(isOn: Binding(get: { loginMgr.isEnabled }, set: { newVal in
                do {
                    try loginMgr.setEnabled(newVal)
                } catch {
                    loginMgr.refresh()
                    showError = error.localizedDescription + "\n\nEnsure you’ve added a Login Item helper target embedded at Contents/Library/LoginItems with bundle id: \(LaunchAtLoginManager.helperBundleIdentifier)."
                }
            })) {
                Text("Launch at Login")
            }
        }
        .padding(16)
        .alert(item: Binding(get: {
            showError.map { Err(id: UUID().uuidString, message: $0) }
        }, set: { v in showError = v?.message })) { v in
            Alert(title: Text("Launch at Login"), message: Text(v.message), dismissButton: .default(Text("OK")))
        }
    }
}

private struct Err: Identifiable { let id: String; let message: String }

private struct ProvidersView: View {
    @ObservedObject var vm: SettingsVM
    @State private var isRefreshing = false
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Provider", selection: Binding(get: { vm.s.provider }, set: { vm.s.provider = $0 })) {
                ForEach(ModelProvider.allCases, id: \.self) { p in Text(p.rawValue).tag(p) }
            }
            HStack {
                Picker("Model", selection: Binding(get: { vm.s.model }, set: { vm.s.model = $0 })) {
                    ForEach(vm.s.availableModels, id: \.self) { Text($0).tag($0) }
                }
                Button(isRefreshing ? "Refreshing…" : "Refresh Models") {
                    isRefreshing = true
                    let c: LLMClient
                    switch vm.s.provider {
                    case .nebius: c = NebiusClient(settings: vm.s)
                    case .openai: c = OpenAIClient(settings: vm.s)
                    case .anthropic: c = AnthropicClient(settings: vm.s)
                    case .groq: c = GroqClient(settings: vm.s)
                    }
                    c.listModels { result in
                        DispatchQueue.main.async {
                            isRefreshing = false
                            if case let .success(m) = result { vm.s.availableModels = m }
                        }
                    }
                }
                .disabled(isRefreshing)
            }
            HStack(spacing: 12) {
                SecureField("\(vm.s.provider.rawValue) API Key", text: Binding(
                    get: { vm.s.apiKey(for: vm.s.provider) ?? "" },
                    set: { vm.s.setApiKey($0, for: vm.s.provider) }
                ))
                .textFieldStyle(.roundedBorder)
                Button("Save") { }
            }
            Spacer()
        }
        .padding(16)
    }
}

private struct PromptView: View {
    @ObservedObject var vm: SettingsVM
    @State private var prompt = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Use System Prompt", isOn: Binding(get: { vm.s.useSystemPrompt }, set: { vm.s.useSystemPrompt = $0 }))
            Text("System Prompt")
            TextEditor(text: Binding(
                get: { vm.s.systemPrompt },
                set: { vm.s.systemPrompt = $0 }
            ))
            .font(.system(.body, design: .monospaced))
            .frame(minHeight: 200)
            Spacer()
        }
        .padding(16)
    }
}

private struct ClipboardView: View {
    @ObservedObject var vm: SettingsVM
    @State private var quiet = 5.0
    var body: some View {
        Form {
            Stepper(value: Binding(get: { vm.s.quietSeconds }, set: { vm.s.quietSeconds = $0 }), in: 1...30, step: 1) {
                HStack { Text("Accumulation quiet window"); Spacer(); Text("\(Int(vm.s.quietSeconds))s") }
            }
            Stepper(value: Binding(get: { vm.s.ignoreShortCopyBelow }, set: { vm.s.ignoreShortCopyBelow = $0 }), in: 0...20, step: 1) {
                HStack { Text("Ignore copies shorter than"); Spacer(); Text("\(vm.s.ignoreShortCopyBelow) chars") }
            }
            TextField("Delimiter between copies", text: Binding(get: { vm.s.delimiter }, set: { vm.s.delimiter = $0 }))
            Stepper(value: Binding(get: { vm.s.maxChars }, set: { vm.s.maxChars = $0 }), in: 1000...50000, step: 500) {
                HStack { Text("Max accumulated characters"); Spacer(); Text("\(vm.s.maxChars)") }
            }
        }
        .padding(16)
    }
}

private struct AdvancedView: View {
    @ObservedObject var vm: SettingsVM
    var body: some View {
        Form {
            Toggle("Redact emails", isOn: Binding(get: { vm.s.redactEmails }, set: { vm.s.redactEmails = $0 }))
            Toggle("Redact URLs", isOn: Binding(get: { vm.s.redactURLs }, set: { vm.s.redactURLs = $0 }))
            Toggle("Redact long numbers", isOn: Binding(get: { vm.s.redactNumbers }, set: { vm.s.redactNumbers = $0 }))
        }
        .padding(16)
    }
}

fileprivate extension View {
    func settingTag(_ page: SettingsPage, selection: Binding<SettingsPage>) -> some View {
        self
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selection.wrappedValue == page ? Color.white.opacity(0.12) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .onTapGesture { selection.wrappedValue = page }
    }
}
