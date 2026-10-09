import SwiftUI
import AppKit
import DoclinCore

private let ink = Color(red: 0.11, green: 0.16, blue: 0.23)
private let canvas = Color(red: 0.965, green: 0.975, blue: 0.99)
private let accent = Color(red: 0.255, green: 0.424, blue: 0.78)
private let mutedInk = Color(red: 0.40, green: 0.46, blue: 0.54)

struct DoclinView: View {
    private static let logo: NSImage? = {
        guard let url = Bundle.main.url(forResource: "DoclinLogo", withExtension: "png") else { return nil }
        return NSImage(contentsOf: url)
    }()
    @ObservedObject var model: AppModel
    @State private var apiKey = ""
    @State private var codexPath = ""
    @State private var settingsRoute = "Voice & AI"
    @State private var hoveredTab: String?
    private let settingsDestinations = [
        ("Dictation", "mic", "Dictation settings"), ("Voice", "speaker.wave.2", "Voice & AI"),
        ("Agents", "terminal", "Connections"), ("General", "slider.horizontal.3", "Preferences"),
        ("Cloud", "cloud", "Cloud"), ("Troubleshooting", "wrench", "Troubleshooting"), ("Privacy", "lock.shield", "Privacy")
    ]
    private var selectedSettingsRoute: String { model.tab == "Settings" ? settingsRoute : model.tab }
    private var section: String {
        ["Dictation settings", "Connections", "Voice & AI", "Preferences", "Cloud", "Troubleshooting", "Privacy", "Settings"].contains(model.tab) ? "Settings" : model.tab
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if let logo = Self.logo {
                    Image(nsImage: logo).resizable().scaledToFit().frame(width: 24, height: 24)
                } else {
                    Image(systemName: "waveform").foregroundColor(accent)
                }
                Text("Doclin").font(.system(size: 17, weight: .semibold))
                Spacer()
            }.padding(.horizontal, 24).padding(.top, 18).padding(.bottom, 16)
            HStack(spacing: 6) {
                ForEach(["Dictation", "Activity", "Settings"], id: \.self) { name in
                    Button { model.tab = name } label: {
                        Text(name == "Activity" ? "Agent updates" : name).font(.system(size: 13, weight: .medium))
                            .frame(maxWidth: .infinity).padding(.vertical, 9)
                            .background(section == name ? Color.white : hoveredTab == name ? Color.white.opacity(0.55) : .clear, in: RoundedRectangle(cornerRadius: 7))
                            .contentShape(Rectangle())
                    }.buttonStyle(DoclinTabButton()).onHover { hoveredTab = $0 ? name : nil }
                        .accessibilityValue(section == name ? "Selected" : "")
                }
            }.padding(4).background(ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 24).padding(.bottom, 18)
            if section == "Settings" {
                VStack(alignment: .leading, spacing: 16) {
                    if !model.notice.isEmpty { notice }
                    settingsPage
                }.padding(.horizontal, 24).padding(.bottom, 20)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if !model.notice.isEmpty { notice }
                        if model.tab == "Dictation" { DictationView(controller: model.dictation, model: model) }
                        else { activity }
                    }.padding(.horizontal, 24).padding(.bottom, 20)
                }
            }
        }.frame(minWidth: 620, minHeight: 520).background(canvas).foregroundColor(ink).preferredColorScheme(.light)
        .buttonStyle(.bordered).controlSize(.regular)
        .onAppear { codexPath = model.preferences.codexHome }
        .onChange(of: model.tab) { route in
            if settingsDestinations.contains(where: { $0.2 == route }) { settingsRoute = route }
        }
    }
    private var notice: some View {
        HStack(alignment: .top) {
            Text(model.notice).font(.system(size: 12)).foregroundColor(mutedInk)
            Spacer()
            Button { model.notice = "" } label: {
                Image(systemName: "xmark").frame(width: 24, height: 24).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel("Dismiss notice")
        }.padding(12).background(accent.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }
    private var settingsPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                VStack(spacing: 4) {
                    ForEach(settingsDestinations, id: \.2) { item in
                        DoclinSettingsNavigationItem(title: item.0, systemImage: item.1, selected: selectedSettingsRoute == item.2) {
                            settingsRoute = item.2; model.tab = item.2
                        }
                    }
                }.frame(width: 152)
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        switch selectedSettingsRoute {
                        case "Dictation settings": DictationSettingsView(controller: model.dictation, model: model)
                        case "Connections": connections
                        case "Preferences": preferences
                        case "Cloud": cloudSettings
                        case "Troubleshooting": DictationTroubleshootingView(controller: model.dictation)
                        case "Privacy": privacySettings
                        default: voiceSettings
                        }
                    }.padding(.trailing, 2).padding(.bottom, 12).frame(maxWidth: .infinity, alignment: .leading)
                }.id(selectedSettingsRoute)
            }.frame(maxHeight: .infinity, alignment: .top)
        }.frame(maxHeight: .infinity, alignment: .top)
    }
    private var activity: some View {
        VStack(alignment: .leading, spacing: 16) {
            DoclinCard {
                DoclinStatusRow(model.preferences.muted ? "Announcements paused" : model.status,
                    enabled: Binding(get: { !model.preferences.muted }, set: { enabled in
                        if model.preferences.muted != !enabled { model.toggleMute() }
                    })) {
                    if model.speaking || model.pendingCount > 0 { Button("Stop") { model.stopAll() } }
                }
                if model.preferences.useAI || model.preferences.aiVoice {
                    DoclinCloudNotice("Text sent to OpenAI")
                }
            }
            DoclinHistoryCard(title: "Recent updates", emptyMessage: "New Codex and Claude updates appear here.", isEmpty: model.history.isEmpty, clear: { model.clearHistory() }) {
                ForEach(model.history) { row in
                    VStack(alignment: .leading, spacing: 8) {
                        DoclinHistoryMetadata(source: row.event.source, state: row.state, timestamp: row.event.timestamp)
                        Text(row.text).font(.system(size: 14)).textSelection(.enabled)
                    }.padding(.vertical, 12)
                    Divider()
                }
            }
        }
    }
    private var connections: some View {
        VStack(alignment: .leading, spacing: 12) {
            DoclinSettingsGroup {
                DoclinSettingRow("Codex") { Toggle("Announce Codex", isOn: binding(\.codexEnabled)).labelsHidden().toggleStyle(.switch).controlSize(.small) }
                DoclinSettingNote("Desktop + CLI · \(model.watchedCount) recent sessions observed. Reads local sessions without changing Codex settings.")
                DoclinSettingRow("Session folder") { TextField("Codex home", text: $codexPath).textFieldStyle(.roundedBorder) }
                DoclinSettingRow("Apply folder") {
                    Button("Apply path") { model.preferences.codexHome = codexPath; model.save(); model.restartWatcher() }
                        .disabled(codexPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                DoclinSettingRow("Claude Code") { Toggle("Announce Claude Code", isOn: binding(\.claudeEnabled)).labelsHidden().toggleStyle(.switch).controlSize(.small) }
                DoclinSettingRow("Connection") { Button(model.claudeInstalled ? "Disconnect Claude" : "Connect Claude") { model.connectClaude(!model.claudeInstalled) } }
                DoclinSettingNote(model.claudeInstalled ? "Hooks installed. Existing Claude settings are preserved." : "Connect once, then restart Claude sessions. Existing hooks are preserved.")
            }
            DoclinSettingNote("Pause other narration apps to avoid duplicate speech. Unknown session events are ignored.")
        }.onAppear { codexPath = model.preferences.codexHome }
    }
    private var voiceSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            DoclinSettingsGroup {
                DoclinSettingRow("Local voice") {
                    Picker("Local voice", selection: binding(\.systemVoice)) {
                        ForEach(LocalVoiceChoice.choices, id: \.key) { Text($0.name).tag($0.key) }
                        ForEach(model.voices, id: \.identifier) { Text("\($0.name) · \($0.language)").tag($0.identifier) }
                    }.labelsHidden()
                }
                DoclinSettingRow("Output") { Text(model.outputName).font(.system(size: 12)).foregroundColor(mutedInk).fixedSize(horizontal: false, vertical: true) }
                DoclinSettingRow("Volume") {
                    HStack(spacing: 8) {
                        Slider(value: binding(\.volume), in: 0...1).accessibilityLabel("Volume")
                        Text("\(Int(model.preferences.volume * 100))%").frame(width: 35)
                    }.font(.system(size: 12))
                }
                DoclinSettingRow("Speed") {
                    HStack(spacing: 8) {
                        Slider(value: binding(\.rate), in: 0.8...1.5).accessibilityLabel("Speed")
                        Text(String(format: "%.1f×", model.preferences.rate)).frame(width: 35)
                    }.font(.system(size: 12))
                }
                DoclinSettingRow("Preview") { Button("Preview voice") { model.preview() }.disabled(model.preferences.muted) }
            }
            DoclinSettingNote(model.preferences.muted ? "Turn on Agent updates to preview your voice. Local voices run on your Mac." : "Local voices run on your Mac. If playback fails, the update stays in Agent updates.")
        }
    }
    private var cloudSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            DoclinSettingNote("Optional · API usage is billed to your OpenAI account. AI summaries send up to 600 characters of task context and 8,000 characters of the final response. AI voice sends the spoken sentence.")
            DoclinSettingsGroup {
                DoclinSettingRow("API key") { SecureField(model.hasKey ? "Replace API key" : "OpenAI API key", text: $apiKey).textFieldStyle(.roundedBorder) }
                DoclinSettingRow("Keychain") {
                    HStack {
                        Button("Save key") { model.saveKey(apiKey); apiKey = "" }.disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        if model.hasKey { Button("Remove key") { model.removeKey() } }
                    }
                }
                DoclinSettingRow("Saved key") { Text(model.hasKey ? "Stored in Keychain" : "No key saved").font(.system(size: 12)).foregroundColor(mutedInk) }
                DoclinSettingRow("AI summaries") { Toggle("Summarize with AI", isOn: binding(\.useAI)).labelsHidden().toggleStyle(.switch).controlSize(.small).disabled(!model.hasKey) }
                DoclinSettingRow("AI voice") { Toggle("Use an AI-generated voice", isOn: binding(\.aiVoice)).labelsHidden().toggleStyle(.switch).controlSize(.small).disabled(!model.hasKey) }
                if model.preferences.aiVoice {
                    DoclinSettingRow("Cloud voice") {
                        Picker("AI voice", selection: binding(\.voice)) { ForEach(["coral", "marin", "cedar", "sage", "alloy"], id: \.self) { Text($0.capitalized).tag($0) } }.labelsHidden()
                    }
                }
            }
            DoclinSettingNote("GPT-4o mini summaries · GPT-4o mini TTS. Speech is AI generated. Dictation processing and text cleanup are selected under Dictation.")
        }
    }
    private var preferences: some View {
        VStack(alignment: .leading, spacing: 12) {
            DoclinSettingsGroup {
                DoclinSettingRow("Start at login") { Toggle("Start Doclin at login", isOn: Binding(get: { model.loginEnabled }, set: { model.setLogin($0) })).labelsHidden().toggleStyle(.switch).controlSize(.small) }
                DoclinSettingRow("Update length") {
                    Picker("Maximum length", selection: binding(\.wordLimit)) { Text("15 words").tag(15); Text("20 words").tag(20); Text("25 words").tag(25) }.labelsHidden()
                }
                DoclinSettingRow("Queue expiry") {
                    Picker("Drop queued updates after", selection: binding(\.expiry)) { Text("15 seconds").tag(15.0); Text("30 seconds").tag(30.0); Text("60 seconds").tag(60.0) }.labelsHidden()
                }
                DoclinSettingRow("Skip projects") { TextField("Folder names, separated by commas", text: binding(\.excludedProjects)).textFieldStyle(.roundedBorder) }
                DoclinSettingRow("History") { Button("Clear updates") { model.clearHistory() } }
            }
            DoclinSettingNote("Doclin \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development") · macOS 13+\nDevelopment-signed preview, not Apple notarized.")
        }
    }
    private var privacySettings: some View {
        DoclinSettingsGroup {
            DoclinSettingRow("Processing") { Text("Local by default").font(.system(size: 12)).foregroundColor(mutedInk) }
            DoclinSettingNote("Local dictation and voices stay on your Mac. Optional cloud features send selected audio or text to OpenAI.")
            DoclinSettingRow("History") { Text("Session only").font(.system(size: 12)).foregroundColor(mutedInk) }
            DoclinSettingNote("The last 30 dictations and agent updates stay in memory and clear on quit. Hook messages use a private local inbox while Doclin runs; crash leftovers are removed on the next launch or hook.")
            DoclinSettingRow("API keys") { Text("macOS Keychain").font(.system(size: 12)).foregroundColor(mutedInk) }
            DoclinSettingNote("Cloud requests use OpenAI directly. There is no Doclin server or analytics. AI summaries request store: false; OpenAI's API data policies still apply.")
        }
    }
    private func binding<T>(_ path: WritableKeyPath<Preferences, T>) -> Binding<T> {
        Binding(get: { model.preferences[keyPath: path] }, set: { model.preferences[keyPath: path] = $0; model.save() })
    }

}
struct DoclinButton: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .medium)).padding(.horizontal, 15).padding(.vertical, 10)
            .foregroundColor(isEnabled ? .white : mutedInk)
            .background(isEnabled ? accent.opacity(configuration.isPressed ? 0.8 : 1) : ink.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
    }
}
struct DoclinTabButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.65 : 1).contentShape(Rectangle())
    }
}
// Main pages share status typography, toggle placement and spacing.
struct DoclinStatusRow<Accessory: View>: View {
    let title: String
    @Binding var enabled: Bool
    let accessory: Accessory
    init(_ title: String, enabled: Binding<Bool>, @ViewBuilder accessory: () -> Accessory) {
        self.title = title; self._enabled = enabled; self.accessory = accessory()
    }
    var body: some View {
        HStack {
            Text(title).font(.system(size: 15, weight: .semibold))
            Spacer()
            Toggle("Enabled", isOn: $enabled).toggleStyle(.switch).controlSize(.small)
            accessory
        }
    }
}
struct DoclinCloudNotice: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Label(text, systemImage: "cloud").font(.system(size: 11)).foregroundColor(.secondary)
    }
}
struct DoclinCard<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading).doclinSurface()
    }
}
extension View {
    func doclinSurface() -> some View {
        background(Color.white, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(ink.opacity(0.06), lineWidth: 1).allowsHitTesting(false))
    }
}

struct DoclinHistoryCard<Content: View>: View {
    let title: String
    let emptyMessage: String
    let isEmpty: Bool
    var canClear = true
    let clear: () -> Void
    @ViewBuilder let content: Content
    var body: some View {
        DoclinCard {
            HStack {
                Text(title).font(.system(size: 15, weight: .semibold))
                Spacer()
                if !isEmpty { Button("Clear", action: clear).disabled(!canClear) }
            }
            if isEmpty {
                Text(emptyMessage).font(.system(size: 13)).foregroundColor(mutedInk)
                    .padding(.vertical, 16).frame(maxWidth: .infinity, alignment: .leading)
            } else { content }
        }
    }
}
struct DoclinHistoryMetadata: View {
    let source: String
    let state: String
    let timestamp: Date
    var body: some View {
        HStack {
            Text(source).font(.system(size: 11, weight: .medium))
            Text(state).foregroundColor(mutedInk)
            Spacer()
            Text(timestamp, style: .time).foregroundColor(mutedInk)
        }.font(.system(size: 11))
    }
}

struct DoclinSettingsNavigationItem: View {
    let title: String
    let systemImage: String
    let selected: Bool
    let action: () -> Void
    @State private var hovered = false
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage).font(.system(size: 12, weight: selected ? .semibold : .medium)).lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading).padding(.horizontal, 8)
                .foregroundColor(selected ? accent : ink)
                .background(selected ? accent.opacity(0.10) : hovered ? ink.opacity(0.04) : .clear, in: RoundedRectangle(cornerRadius: 7))
                .contentShape(Rectangle())
        }.buttonStyle(DoclinTabButton()).onHover { hovered = $0 }
            .accessibilityValue(selected ? "Selected" : "")
    }
}
struct DoclinSettingsGroup<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }.padding(.horizontal, 14).doclinSurface()
    }
}
struct DoclinSettingRow<Content: View>: View {
    let title: String
    let content: Content
    init(_ title: String, @ViewBuilder content: () -> Content) { self.title = title; self.content = content() }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(title).font(.system(size: 12, weight: .medium)).frame(width: 100, alignment: .leading)
                content.frame(maxWidth: .infinity, alignment: .trailing)
            }.frame(minHeight: 42).padding(.vertical, 4)
            Divider().opacity(0.45)
        }
    }
}
struct DoclinSettingNote: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(.system(size: 11)).foregroundColor(mutedInk).fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 12).frame(maxWidth: .infinity, alignment: .leading)
    }
}
