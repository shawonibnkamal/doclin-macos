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
    @State private var allUpdates = false
    @State private var cloudOptions = false
    private var section: String {
        ["Connections", "Voice & AI", "Preferences", "Settings"].contains(model.tab) ? "Settings" : model.tab
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
                            .background(section == name ? Color.white : .clear, in: RoundedRectangle(cornerRadius: 7))
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
            }.padding(4).background(ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 24).padding(.bottom, 18)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !model.notice.isEmpty {
                        HStack(alignment: .top) {
                            Text(model.notice).font(.system(size: 12)).foregroundColor(mutedInk)
                            Spacer()
                            Button { model.notice = "" } label: { Image(systemName: "xmark") }
                                .buttonStyle(.plain).accessibilityLabel("Dismiss notice")
                        }.padding(12).background(accent.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                    }
                    switch model.tab {
                    case "Dictation": DictationView(controller: model.dictation, model: model)
                    case "Connections", "Voice & AI", "Preferences", "Settings": settingsPage
                    default: activity
                    }
                }.padding(.horizontal, 24).padding(.bottom, 20)
            }
        }.frame(minWidth: 620, minHeight: 520).background(canvas).foregroundColor(ink).preferredColorScheme(.light)
        .onAppear { codexPath = model.preferences.codexHome }
    }
    private var settingsPage: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings").font(.system(size: 24, weight: .semibold)).padding(.bottom, 4)
            settingSection("Voice", systemImage: "speaker.wave.2", route: "Voice & AI") { voiceSettings }
            settingSection("Agents", systemImage: "terminal", route: "Connections") { connections }
            settingSection("General", systemImage: "slider.horizontal.3", route: "Preferences") { preferences }
        }
    }
    private func settingSection<Content: View>(_ title: String, systemImage: String, route: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        DisclosureGroup(isExpanded: Binding(get: { model.tab == route }, set: { model.tab = $0 ? route : "Settings" })) {
            if model.tab == route { content().padding(.top, 12) }
        } label: {
            Label(title, systemImage: systemImage).font(.system(size: 14, weight: .medium))
        }.padding(16).background(Color.white, in: RoundedRectangle(cornerRadius: 10))
    }
    private var activity: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Agent updates").font(.system(size: 24, weight: .semibold))
                Spacer()
                Toggle("Enabled", isOn: Binding(get: { !model.preferences.muted }, set: { enabled in
                    if model.preferences.muted != !enabled { model.toggleMute() }
                })).toggleStyle(.switch).controlSize(.small)
            }
            HStack {
                Text(model.preferences.muted ? "Announcements paused" : model.status).font(.system(size: 12)).foregroundColor(mutedInk)
                Spacer()
                if model.speaking || model.pendingCount > 0 { Button("Stop") { model.stopAll() } }
                Button("Preview voice") { model.preview() }.disabled(model.preferences.muted)
                Button("Connect agents") { model.tab = "Connections" }
            }
            if model.history.isEmpty {
                Text("New Codex and Claude updates appear here.").font(.system(size: 14)).foregroundColor(mutedInk).padding(.vertical, 32)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(model.history.prefix(allUpdates ? model.history.count : 3))) { row in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(row.event.source).font(.system(size: 11, weight: .medium))
                                Text(row.state).font(.system(size: 11)).foregroundColor(mutedInk)
                                Spacer()
                                Text(row.event.timestamp, style: .time).font(.system(size: 11)).foregroundColor(mutedInk)
                            }
                            Text(row.text).font(.system(size: 14)).textSelection(.enabled)
                        }.padding(.vertical, 13)
                        Divider()
                    }
                }
                HStack {
                    if model.history.count > 3 { Button(allUpdates ? "Show less" : "Show all updates") { allUpdates.toggle() } }
                    Spacer()
                    Button("Clear") { model.clearHistory() }
                }.font(.system(size: 12))
            }
        }
    }
    private var connections: some View {
        VStack(alignment: .leading, spacing: 20) {
            card {
                HStack { Label("Codex", systemImage: "terminal").font(.system(size: 17, weight: .semibold)); Spacer(); Toggle("Announce", isOn: binding(\.codexEnabled)).toggleStyle(.switch).controlSize(.small) }
                Text("Desktop + CLI").font(.system(size: 12, weight: .medium)).foregroundColor(accent)
                Text("Reads new local sessions. No Codex settings are changed.").font(.system(size: 12)).foregroundColor(mutedInk).fixedSize(horizontal: false, vertical: true)
                HStack { Image(systemName: "checkmark.circle.fill").foregroundColor(accent); Text("\(model.watchedCount) recent sessions observed").font(.system(size: 12)) }
                DisclosureGroup("Advanced") {
                  HStack {
                    TextField("Codex home", text: $codexPath).textFieldStyle(.roundedBorder)
                    Button("Apply path") { model.preferences.codexHome = codexPath; model.save(); model.restartWatcher() }
                  }
                }.onAppear { codexPath = model.preferences.codexHome }
                Text("Desktop session formats can change. Unknown events are ignored.").font(.system(size: 10)).foregroundColor(mutedInk)
            }
            card {
                HStack { Label("Claude Code", systemImage: "asterisk").font(.system(size: 17, weight: .semibold)); Spacer(); Toggle("Announce", isOn: binding(\.claudeEnabled)).toggleStyle(.switch).controlSize(.small) }
                Text(model.claudeInstalled ? "Hooks installed" : "One-time connection").font(.system(size: 12, weight: .medium)).foregroundColor(accent)
                Text("Adds Doclin hooks and preserves existing settings. Restart Claude sessions after connecting.").font(.system(size: 12)).foregroundColor(mutedInk).fixedSize(horizontal: false, vertical: true)
                Button(model.claudeInstalled ? "Disconnect Claude" : "Connect Claude Code") { model.connectClaude(!model.claudeInstalled) }.buttonStyle(DoclinButton())
            }
            Text("Pause other narration apps to avoid duplicate speech.").font(.system(size: 12)).foregroundColor(mutedInk).lineSpacing(3)
        }
    }
    private var voiceSettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            card {
                Text("Local voice").font(.system(size: 15, weight: .semibold))
                Text("Output: \(model.outputName)").font(.system(size: 12)).foregroundColor(mutedInk)
                Picker("Voice", selection: binding(\.systemVoice)) {
                    ForEach(LocalVoiceChoice.choices, id: \.key) { Text($0.name).tag($0.key) }
                    ForEach(model.voices, id: \.identifier) { Text("\($0.name) · \($0.language)").tag($0.identifier) }
                }
                Text("Runs on your Mac. If playback fails, the update stays in Agent updates.").font(.system(size: 11)).foregroundColor(mutedInk)
                HStack { Text("Volume").frame(width: 65, alignment: .leading); Slider(value: binding(\.volume), in: 0...1); Text("\(Int(model.preferences.volume * 100))%").frame(width: 35) }.font(.system(size: 12))
                HStack { Text("Speed").frame(width: 65, alignment: .leading); Slider(value: binding(\.rate), in: 0.8...1.5); Text(String(format: "%.1f×", model.preferences.rate)).frame(width: 35) }.font(.system(size: 12))
                Button("Preview voice") { model.preview() }.buttonStyle(DoclinButton())
            }
            DisclosureGroup("Cloud features", isExpanded: $cloudOptions) {
              card {
                HStack { Text("Cloud features").font(.system(size: 15, weight: .semibold)); Spacer(); Text("OPTIONAL").font(.system(size: 9, design: .monospaced)).foregroundColor(mutedInk) }
                Text("AI summaries send up to 600 characters of task context, and up to 8,000 characters of the final response to OpenAI. AI voice sends only the spoken sentence. API usage is billed to your account.").font(.system(size: 12)).foregroundColor(mutedInk).fixedSize(horizontal: false, vertical: true)
                if model.hasKey {
                    HStack { Label("API key saved in Keychain", systemImage: "lock.fill").font(.system(size: 12)).foregroundColor(accent); Spacer(); Button("Remove key") { model.removeKey() }.font(.system(size: 11)) }
                }
                HStack { SecureField(model.hasKey ? "Replace API key" : "OpenAI API key", text: $apiKey).textFieldStyle(.roundedBorder); Button("Save key") { model.saveKey(apiKey); apiKey = "" } }
                Toggle("Summarize with AI", isOn: binding(\.useAI)).disabled(!model.hasKey)
                Text("GPT-4o mini · one short sentence, with the result or blocker.").font(.system(size: 11)).foregroundColor(mutedInk)
                Toggle("Use an AI-generated voice", isOn: binding(\.aiVoice)).disabled(!model.hasKey)
                if model.preferences.aiVoice {
                    Picker("AI voice", selection: binding(\.voice)) { ForEach(["coral", "marin", "cedar", "sage", "alloy"], id: \.self) { Text($0.capitalized).tag($0) } }
                    Text("GPT-4o mini TTS · synthetic speech, not a human voice.").font(.system(size: 11)).foregroundColor(mutedInk)
                }
              }
            }.onAppear { cloudOptions = model.preferences.useAI || model.preferences.aiVoice }
        }
    }
    private var preferences: some View {
        VStack(alignment: .leading, spacing: 20) {
            card {
                Toggle("Start Doclin at login", isOn: Binding(get: { model.loginEnabled }, set: { model.setLogin($0) }))
                DisclosureGroup("Announcement settings") {
                  VStack(alignment: .leading, spacing: 12) {
                Picker("Maximum length", selection: binding(\.wordLimit)) { Text("15 words").tag(15); Text("20 words").tag(20); Text("25 words").tag(25) }
                Picker("Drop queued updates after", selection: binding(\.expiry)) { Text("15 seconds").tag(15.0); Text("30 seconds").tag(30.0); Text("60 seconds").tag(60.0) }
                Text("Skip these projects").font(.system(size: 12, weight: .medium))
                TextField("Project folder names, separated by commas", text: binding(\.excludedProjects)).textFieldStyle(.roundedBorder)
                  }.padding(.top, 10)
                }
            }
            card {
                Label("Your conversations stay yours", systemImage: "lock.shield").font(.system(size: 15, weight: .semibold))
                Text("Local dictation and voices stay on your Mac. Optional cloud features send selected audio or text to OpenAI.").font(.system(size: 12)).foregroundColor(mutedInk).lineSpacing(4)
                DisclosureGroup("Privacy details") {
                  Text("Recent announcements are held in memory and cleared on quit. Hook messages use a private local inbox while Doclin runs. Crash leftovers are removed on the next launch or hook. API keys live in Keychain. Cloud requests use OpenAI directly; there is no Doclin server or analytics.").font(.system(size: 12)).foregroundColor(mutedInk).lineSpacing(4)
                Text("AI summaries request store: false. OpenAI’s own API data policies still apply.").font(.system(size: 11)).foregroundColor(mutedInk)
                }
                Button("Clear recent announcements") { model.clearHistory() }
            }
            Text("Doclin \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development") · macOS 13 or later\nPersonal preview build. Public distribution requires Developer ID signing and notarization.").font(.system(size: 11)).foregroundColor(mutedInk).lineSpacing(4)
        }
    }
    private func binding<T>(_ path: WritableKeyPath<Preferences, T>) -> Binding<T> {
        Binding(get: { model.preferences[keyPath: path] }, set: { model.preferences[keyPath: path] = $0; model.save() })
    }
    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12, content: content).padding(18).frame(maxWidth: .infinity, alignment: .leading).background(Color.white, in: RoundedRectangle(cornerRadius: 13))
    }
}
struct DoclinButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .medium)).padding(.horizontal, 15).padding(.vertical, 10).foregroundColor(.white).background(accent.opacity(configuration.isPressed ? 0.8 : 1), in: RoundedRectangle(cornerRadius: 8))
    }
}
