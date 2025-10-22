import SwiftUI

struct OverlaySettingsView: View {
    let settings: SettingsStore

    @State private var width: Double
    @State private var fontSize: Double
    @State private var sensitivity: Double
    @State private var autoHide: Double
    @State private var placement: OverlayPlacement
    @State private var textColor: String
    @State private var autoShow: Bool
    @State private var excludeShare: Bool

    init(settings: SettingsStore) {
        self.settings = settings
        _width = State(initialValue: Double(settings.overlayWidth))
        _fontSize = State(initialValue: settings.overlayFontSize)
        _sensitivity = State(initialValue: settings.overlayScrollSensitivity)
        _autoHide = State(initialValue: settings.overlayAutoHideSeconds)
        _placement = State(initialValue: settings.overlayPlacement)
        _textColor = State(initialValue: settings.overlayTextColor)
        _autoShow = State(initialValue: settings.overlayAutoShow)
        _excludeShare = State(initialValue: settings.overlayExcludeFromScreenShare)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle("Auto-show on response", isOn: Binding(get: { autoShow }, set: { autoShow = $0; settings.overlayAutoShow = $0 }))

            HStack {
                Text("Width")
                Slider(value: Binding(get: { width }, set: { width = $0; settings.overlayWidth = Int($0) }), in: 200...1200)
                Text("\(Int(width)) px").frame(width: 80, alignment: .trailing)
            }

            HStack {
                Text("Font Size")
                Slider(value: Binding(get: { fontSize }, set: { fontSize = $0; settings.overlayFontSize = $0 }), in: 10...36)
                Text("\(Int(fontSize)) pt").frame(width: 80, alignment: .trailing)
            }

            HStack {
                Text("Scroll Sensitivity")
                Slider(value: Binding(get: { sensitivity }, set: { sensitivity = $0; settings.overlayScrollSensitivity = $0 }), in: 5...100)
                Text(sensitivityLabel).frame(width: 80, alignment: .trailing)
            }

            HStack {
                Text("Auto Hide")
                Picker("Auto Hide", selection: Binding(get: { autoHide }, set: { autoHide = $0; settings.overlayAutoHideSeconds = $0 })) {
                    Text("Off").tag(0.0)
                    Text("1 min").tag(60.0)
                    Text("5 min").tag(300.0)
                    Text("10 min").tag(600.0)
                }
                .pickerStyle(.segmented)
            }

            HStack {
                Text("Placement")
                Picker("Placement", selection: Binding(get: { placement }, set: { placement = $0; settings.overlayPlacement = $0 })) {
                    ForEach(OverlayPlacement.allCases, id: \.self) { p in
                        Text(p.rawValue.capitalized).tag(p)
                    }
                }
                .pickerStyle(.segmented)
            }

            HStack {
                Text("Text Color")
                Picker("Text Color", selection: Binding(get: { textColor }, set: { textColor = $0; settings.overlayTextColor = $0 })) {
                    Text("Black").tag("black")
                    Text("White").tag("white")
                    Text("Label").tag("label")
                }
                .pickerStyle(.segmented)
            }

            Toggle("Exclude from Screen Sharing", isOn: Binding(get: { excludeShare }, set: { excludeShare = $0; settings.overlayExcludeFromScreenShare = $0 }))

            Spacer()
        }
        .padding(20)
        .frame(minWidth: 500, minHeight: 380)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var sensitivityLabel: String {
        if sensitivity < 15 { return "Low" }
        if sensitivity < 45 { return "Medium" }
        return "High"
    }
}

