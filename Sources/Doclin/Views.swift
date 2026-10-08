import SwiftUI
import AppKit
import DoclinCore

private let ink = Color(red: 0.10, green: 0.14, blue: 0.18)
private let canvas = Color(red: 0.96, green: 0.965, blue: 0.95)
private let accent = Color(red: 0.17, green: 0.38, blue: 0.31)
private let mutedInk = Color(red: 0.43, green: 0.48, blue: 0.46)

struct DoclinView: View {
    @ObservedObject var model: AppModel
    @State private var apiKey = ""
    @State private var codexPath = ""
    var body: some View {
        HStack(spacing: 0) {
            sidebar
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(model.tab.uppercased()).font(.system(size: 11, weight: .semibold, design: .monospaced)).tracking(2).foregroundColor(mutedInk)
                    Spacer()
                    Circle().fill(model.preferences.muted ? .orange : accent).frame(width: 6, height: 6)
                    Text(model.preferences.muted ? "Paused" : "Listening for finishes").font(.system(size: 12)).foregroundColor(mutedInk)
                }.padding(.horizontal, 32).padding(.top, 28).padding(.bottom, 22)
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        if !model.notice.isEmpty {
                            HStack(alignment: .top) {
                                Image(systemName: "info.circle").foregroundColor(accent)
                                Text(model.notice).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
                                Spacer()
                                Button { model.notice = "" } label: { Image(systemName: "xmark") }.buttonStyle(.plain).accessibilityLabel("Dismiss notice")
                            }.padding(14).background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                        }
                        switch model.tab {
                        case "Dictation": DictationView(controller: model.dictation, model: model)
                        case "Connections": connections
                        case "Voice & AI": voiceSettings
                        case "Preferences": preferences
                        default: activity
                        }
                    }.padding(.horizontal, 32).padding(.bottom, 32)
                }
                HStack {
                    Text(model.status).lineLimit(1)
                    Spacer()
                    Text("DOCLIN / 0.4.7").font(.system(size: 10, design: .monospaced)).tracking(1)
                }.font(.system(size: 11)).foregroundColor(mutedInk).padding(.horizontal, 32).padding(.vertical, 14).background(Color.white.opacity(0.6))
            }.frame(maxWidth: .infinity, maxHeight: .infinity).background(canvas)
        }.frame(minWidth: 890, minHeight: 650).foregroundColor(ink).preferredColorScheme(.light)
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "waveform").font(.system(size: 24, weight: .medium)).foregroundColor(Color(red: 0.78, green: 0.88, blue: 0.68))
                Text("doclin").font(.system(size: 27, weight: .semibold, design: .rounded)).tracking(-1)
            }.padding(.top, 36).padding(.bottom, 8)
            Text("A little less checking.").font(.system(size: 12)).foregroundColor(.white.opacity(0.5)).padding(.bottom, 44)
            ForEach([("Activity", "waveform.path"), ("Dictation", "mic"), ("Connections", "point.3.connected.trianglepath.dotted"), ("Voice & AI", "speaker.wave.2"), ("Preferences", "slider.horizontal.3")], id: \.0) { name, icon in
                Button { model.tab = name } label: {
                    HStack(spacing: 12) { Image(systemName: icon).frame(width: 18); Text(name).font(.system(size: 13, weight: .medium)); Spacer() }
                        .padding(.horizontal, 13).padding(.vertical, 12)
                        .foregroundColor(model.tab == name ? .white : .white.opacity(0.55))
                        .background(model.tab == name ? .white.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 9))
                        .contentShape(Rectangle())
                }.buttonStyle(.plain).padding(.bottom, 5)
            }
            Spacer()
            VStack(alignment: .leading, spacing: 10) {
                Text(model.preferences.muted ? "Take your time." : "Go do your thing.").font(.system(size: 15, weight: .medium))
                Text("We’ll keep the update short.").font(.system(size: 12)).foregroundColor(.white.opacity(0.5))
                Button { model.toggleMute() } label: {
                    Label(model.preferences.muted ? "Resume announcements" : "Pause announcements", systemImage: model.preferences.muted ? "play.fill" : "pause.fill")
                        .font(.system(size: 11, weight: .medium)).frame(maxWidth: .infinity).padding(.vertical, 11)
                        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                }.buttonStyle(.plain)
            }.padding(.bottom, 25)
            Text("doclin.dev").font(.system(size: 11, design: .monospaced)).foregroundColor(.white.opacity(0.35)).padding(.bottom, 24)
        }.padding(.horizontal, 20).frame(width: 218).background(ink).foregroundColor(.white)
    }
    private func title(_ text: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(text).font(.system(size: 29, weight: .semibold)).tracking(-0.8)
            Text(sub).font(.system(size: 13)).foregroundColor(mutedInk).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
        }
    }
    private var activity: some View {
        VStack(alignment: .leading, spacing: 23) {
            title("Your agents. A few words.", "A short spoken update when a response is ready. Then, quiet.")
            HStack(spacing: 12) {
                stat("CODEX", "\(model.watchedCount)", "recent sessions observed")
                stat("UP NEXT", "\(model.pendingCount)", "fresh announcements")
                stat("VOICE", model.preferences.aiVoice && model.hasKey ? "AI" : (LocalVoiceChoice.speaker(for: model.preferences.systemVoice) != nil ? (model.hasLocalVoice ? "Kokoro" : "Unavailable") : "Mac"), model.preferences.useAI && model.hasKey ? "AI summaries enabled" : "local excerpts · no API cost")
            }
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Label(model.speaking ? "Speaking now" : "Make yourself at home", systemImage: model.speaking ? "waveform" : "sparkle").font(.system(size: 12, weight: .semibold)).foregroundColor(accent)
                    Spacer()
                    Text("UP TO \(model.preferences.wordLimit) WORDS.").font(.system(size: 9, design: .monospaced)).tracking(1).foregroundColor(mutedInk)
                }
                Text(model.history.first(where: { $0.state == "Speaking" })?.text ?? "“Stage labels are fixed. Tests pass; changes are ready for review.”")
                    .font(.system(size: 20, weight: .medium)).lineSpacing(5).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 14) {
                    Button { model.preview() } label: { Label("Preview voice", systemImage: "play.fill") }.buttonStyle(DoclinButton())
                    if model.speaking || model.pendingCount > 0 { Button("Stop playback") { model.stopAll() }.buttonStyle(.plain).font(.system(size: 12)) }
                    Spacer()
                    Text(model.speaking ? "LIVE" : "EXAMPLE").font(.system(size: 9, design: .monospaced)).foregroundColor(mutedInk)
                }
            }.padding(23).background(Color.white, in: RoundedRectangle(cornerRadius: 15)).overlay(RoundedRectangle(cornerRadius: 15).stroke(ink.opacity(0.06)))
            HStack { Text("Recent announcements").font(.system(size: 14, weight: .semibold)); Spacer(); if !model.history.isEmpty { Button("Clear") { model.clearHistory() }.buttonStyle(.plain).font(.system(size: 11)).foregroundColor(mutedInk) } }
            if model.history.isEmpty {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "tray").font(.system(size: 21)).foregroundColor(mutedInk.opacity(0.7))
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Nothing to catch up on.").font(.system(size: 13, weight: .medium))
                        Text("New completions appear here. Old conversations stay quiet.").font(.system(size: 12)).foregroundColor(mutedInk)
                    }
                }.padding(.vertical, 18)
            } else {
                VStack(spacing: 0) {
                    ForEach(model.history) { row in
                        VStack(alignment: .leading, spacing: 9) {
                            HStack {
                                Text(row.event.source.uppercased()).font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1).foregroundColor(accent)
                                Text(row.event.project).font(.system(size: 11)).foregroundColor(mutedInk)
                                Spacer()
                                Text(row.state).font(.system(size: 10)).foregroundColor(row.state == "Speaking" ? accent : mutedInk)
                                Text(row.event.timestamp, style: .time).font(.system(size: 10)).foregroundColor(mutedInk)
                            }
                            Text(row.text).font(.system(size: 13)).lineSpacing(3).textSelection(.enabled)
                            Text(row.mode).font(.system(size: 10)).foregroundColor(mutedInk)
                        }.padding(.vertical, 16)
                        Divider().opacity(0.5)
                    }
                }
            }
        }
    }
    private func stat(_ label: String, _ value: String, _ note: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(label).font(.system(size: 9, weight: .semibold, design: .monospaced)).tracking(1).foregroundColor(mutedInk)
            Text(value).font(.system(size: 28, weight: .medium)).tracking(-1)
            Text(note).font(.system(size: 10)).foregroundColor(mutedInk).lineLimit(1).minimumScaleFactor(0.8)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(17).background(ink.opacity(0.035), in: RoundedRectangle(cornerRadius: 11))
    }
    private var connections: some View {
        VStack(alignment: .leading, spacing: 20) {
            title("Two agents. One quiet place.", "Connect once. Doclin watches for responses and keeps track of which task they belong to.")
            card {
                HStack { Label("Codex", systemImage: "terminal").font(.system(size: 17, weight: .semibold)); Spacer(); Toggle("Announce", isOn: binding(\.codexEnabled)).toggleStyle(.switch).controlSize(.small) }
                Text("Desktop + CLI").font(.system(size: 12, weight: .medium)).foregroundColor(accent)
                Text("Reads new lifecycle events from local session files. No Codex settings are changed. A new turn cancels the previous announcement.").font(.system(size: 12)).foregroundColor(mutedInk).fixedSize(horizontal: false, vertical: true)
                HStack { Image(systemName: "checkmark.circle.fill").foregroundColor(accent); Text("\(model.watchedCount) recent sessions observed").font(.system(size: 12)) }
                HStack {
                    TextField("Codex home", text: $codexPath).textFieldStyle(.roundedBorder)
                    Button("Apply path") { model.preferences.codexHome = codexPath; model.save(); model.restartWatcher() }
                }.onAppear { codexPath = model.preferences.codexHome }
                Text("Desktop session formats can change. Unknown events are ignored.").font(.system(size: 10)).foregroundColor(mutedInk)
            }
            card {
                HStack { Label("Claude Code", systemImage: "asterisk").font(.system(size: 17, weight: .semibold)); Spacer(); Toggle("Announce", isOn: binding(\.claudeEnabled)).toggleStyle(.switch).controlSize(.small) }
                Text(model.claudeInstalled ? "Hooks installed" : "One-time connection").font(.system(size: 12, weight: .medium)).foregroundColor(accent)
                Text("Uses Stop and UserPromptSubmit hooks. Setup backs up your settings and preserves existing hooks. Restart current Claude Code sessions after connecting.").font(.system(size: 12)).foregroundColor(mutedInk).fixedSize(horizontal: false, vertical: true)
                Button(model.claudeInstalled ? "Disconnect Claude" : "Connect Claude Code") { model.connectClaude(!model.claudeInstalled) }.buttonStyle(DoclinButton())
            }
            Text("Using Heard too? Pause its spoken notifications to avoid hearing both apps. Wispr Flow can stay as it is.").font(.system(size: 12)).foregroundColor(mutedInk).lineSpacing(3)
        }
    }
    private var voiceSettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            title("Sounds like less work.", "A warm, natural voice built in. No account, API key, or subscription needed.")
            card {
                Text("Your everyday voice").font(.system(size: 15, weight: .semibold))
                Text("Output: \(model.outputName)").font(.system(size: 12)).foregroundColor(mutedInk)
                Picker("Voice", selection: binding(\.systemVoice)) {
                    ForEach(LocalVoiceChoice.choices, id: \.key) { Text($0.name).tag($0.key) }
                    ForEach(model.voices, id: \.identifier) { Text("\($0.name) · \($0.language)").tag($0.identifier) }
                }
                Text("These voices run on your Mac. Preview each one to choose your preference. If the chosen voice fails, the update stays in Activity instead of switching to a Mac voice.").font(.system(size: 11)).foregroundColor(mutedInk)
                HStack { Text("Volume").frame(width: 65, alignment: .leading); Slider(value: binding(\.volume), in: 0...1); Text("\(Int(model.preferences.volume * 100))%").frame(width: 35) }.font(.system(size: 12))
                HStack { Text("Speed").frame(width: 65, alignment: .leading); Slider(value: binding(\.rate), in: 0.8...1.5); Text(String(format: "%.1f×", model.preferences.rate)).frame(width: 35) }.font(.system(size: 12))
                Button("Preview voice") { model.preview() }.buttonStyle(DoclinButton())
            }
            card {
                HStack { Text("A little AI, if you want it").font(.system(size: 15, weight: .semibold)); Spacer(); Text("OPTIONAL").font(.system(size: 9, design: .monospaced)).foregroundColor(mutedInk) }
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
        }
    }
    private var preferences: some View {
        VStack(alignment: .leading, spacing: 20) {
            title("Quiet by design.", "Make announcements fit the way you work.")
            card {
                Toggle("Start Doclin at login", isOn: Binding(get: { model.loginEnabled }, set: { model.setLogin($0) }))
                Picker("Maximum length", selection: binding(\.wordLimit)) { Text("15 words").tag(15); Text("20 words").tag(20); Text("25 words").tag(25) }
                Picker("Drop queued updates after", selection: binding(\.expiry)) { Text("15 seconds").tag(15.0); Text("30 seconds").tag(30.0); Text("60 seconds").tag(60.0) }
                Text("Skip these projects").font(.system(size: 12, weight: .medium))
                TextField("Project folder names, separated by commas", text: binding(\.excludedProjects)).textFieldStyle(.roundedBorder)
            }
            card {
                Label("Your conversations stay yours", systemImage: "lock.shield").font(.system(size: 15, weight: .semibold))
                Text("With all cloud options off, Doclin makes no network requests. Doclin reads new Codex lifecycle events and receives Claude hook messages. Microphone capture and text insertion are available only through the optional Dictation feature.").font(.system(size: 12)).foregroundColor(mutedInk).lineSpacing(4)
                Text("Recent announcements are held in memory and cleared on quit. Hook messages use a private local inbox while Doclin runs. Crash leftovers are removed on the next launch or hook. API keys live in Keychain. Cloud requests use OpenAI directly; there is no Doclin server or analytics.").font(.system(size: 12)).foregroundColor(mutedInk).lineSpacing(4)
                Text("AI summaries request store: false. OpenAI’s own API data policies still apply.").font(.system(size: 11)).foregroundColor(mutedInk)
                Button("Clear recent announcements") { model.clearHistory() }
            }
            Text("Doclin 0.4.7 · macOS 13 or later\nPersonal preview build. Public distribution requires Developer ID signing and notarization.").font(.system(size: 11)).foregroundColor(mutedInk).lineSpacing(4)
        }
    }
    private func binding<T>(_ path: WritableKeyPath<Preferences, T>) -> Binding<T> {
        Binding(get: { model.preferences[keyPath: path] }, set: { model.preferences[keyPath: path] = $0; model.save() })
    }
    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 15, content: content).padding(22).frame(maxWidth: .infinity, alignment: .leading).background(Color.white, in: RoundedRectangle(cornerRadius: 13))
    }
}
struct DoclinButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .medium)).padding(.horizontal, 15).padding(.vertical, 10).foregroundColor(.white).background(accent.opacity(configuration.isPressed ? 0.8 : 1), in: RoundedRectangle(cornerRadius: 8))
    }
}
