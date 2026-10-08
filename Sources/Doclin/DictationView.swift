import SwiftUI
import Speech
import DoclinCore

struct DictationView: View {
    @ObservedObject var controller: DictationController
    @ObservedObject var model: AppModel
    private let green = Color(red: 0.17, green: 0.38, blue: 0.31)
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 9) {
                Text("Say it. Keep moving.").font(.system(size: 29, weight: .semibold)).tracking(-0.8)
                Text("Hold your shortcut, speak, and release. Your words land in the text field you were using.")
                    .font(.system(size: 13)).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            card {
                HStack {
                    Image(systemName: controller.indicatorState == .ready ? "checkmark.circle.fill" : "mic.badge.plus").foregroundColor(green)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(controller.indicatorTitle).font(.system(size: 16, weight: .semibold))
                        Text(controller.indicatorSubtitle).font(.system(size: 12)).foregroundColor(.secondary)
                    }
                    Spacer()
                }
                Toggle("Play a short sound when the microphone is ready", isOn: Binding(get: { controller.startSoundEnabled }, set: { controller.setStartSound($0) }))
                HStack {
                    Button(controller.recording ? "Finish dictation" : "Start dictation here") { if controller.recording { controller.finish() } else { controller.begin(inApp: true) } }.buttonStyle(DoclinButton()).disabled(controller.busy && !controller.recording)
                    Button("Preview indicator") { controller.previewIndicator() }.disabled(controller.busy)
                }
                Text("A small pill shows microphone activity and elapsed time. Release to finish; click × to cancel. Preview does not record audio.").font(.system(size: 11)).foregroundColor(.secondary)
            }
            card {
                HStack { Label("Voice to text", systemImage: "mic").font(.system(size: 16, weight: .semibold)); Spacer(); Toggle("Enable dictation", isOn: setting(\.enabled)).toggleStyle(.switch).controlSize(.small) }
                HStack {
                    Picker("Hold to talk", selection: setting(\.shortcut)) { ForEach(DictationHotkey.choices, id: \.0) { Text($0.1).tag($0.0) } }
                    Text(controller.shortcutReady ? "Shortcut ready" : "Shortcut off").font(.system(size: 11)).foregroundColor(controller.shortcutReady ? green : .secondary)
                }
                Text("Hold Right Command for a moment to start. Other keys cancel the hold so Command shortcuts still work. Accessibility is required; key contents are never read or saved. Choose another shortcut if it overlaps with another dictation app.").font(.system(size: 11)).foregroundColor(.secondary)
                Toggle("Insert into the original text field automatically", isOn: setting(\.autoInsert))
                Toggle("Use clipboard paste for reliable insertion", isOn: setting(\.clipboardFallback))
                Text("Paste replaces your clipboard with the transcript and leaves it there, so a slow app cannot accidentally paste old clipboard contents.").font(.system(size: 11)).foregroundColor(.secondary)
                Text("If you switch fields or type while it’s processing, Doclin keeps the transcript here. It never presses Send or Return.").font(.system(size: 11)).foregroundColor(.secondary)
            }
            card {
                HStack { Text("One-time setup").font(.system(size: 15, weight: .semibold)); Spacer(); Button("Refresh") { controller.refreshPermissions() }.font(.system(size: 11)) }
                permission("Microphone", detail: "Records only while you dictate.", granted: controller.microphoneGranted, action: { controller.requestMicrophone() })
                if controller.settings.provider == "local" && !controller.modernReady {
                    permission("Speech Recognition", detail: "Required for Apple’s on-device transcription.", granted: controller.speechGranted, action: { controller.requestSpeech() })
                }
                permission("Accessibility", detail: "Enables Right Command and inserts text into other apps.", granted: controller.accessibilityGranted, action: { controller.openAccessibility() })
                Text("If a permission was previously denied, enable it in macOS System Settings. Move Doclin to Applications before granting access for daily use.").font(.system(size: 11)).foregroundColor(.secondary)
                Button("Test insertion in another app (8 seconds)") { controller.testInsertion() }.disabled(controller.busy)
                Button("Open microphone settings") { controller.openMicrophoneSettings() }.font(.system(size: 11))
            }
            card {
                Text("How your words become text").font(.system(size: 15, weight: .semibold))
                Picker("Transcription", selection: setting(\.provider)) { Text("On this Mac · no API cost").tag("local"); Text("OpenAI · your API key").tag("cloud") }
                Picker("Language", selection: setting(\.locale)) {
                    ForEach([("en-US", "English (US)"), ("en-CA", "English (Canada)"), ("en-GB", "English (UK)"), ("fr-FR", "French"), ("es-ES", "Spanish"), ("de-DE", "German"), ("pt-BR", "Portuguese"), ("bn-BD", "Bengali")], id: \.0) { Text($0.1).tag($0.0) }
                }
                if controller.settings.provider == "local" {
                    Text(controller.recognitionEngine).font(.system(size: 12, weight: .medium))
                    if !controller.engineMessage.isEmpty { Text(controller.engineMessage).font(.system(size: 11)).foregroundColor(.secondary) }
                    Text(controller.onDeviceSupported ? "On-device recognition is available. Audio stays on your Mac." : "On-device recognition is not available for this language on this Mac. Choose another language or OpenAI.").font(.system(size: 11)).foregroundColor(.secondary)
                } else {
                    Text("Your recording and vocabulary go directly to OpenAI for transcription with GPT-4o mini transcribe. API usage is billed to your account. Audio files are deleted after reading or cancellation; crash leftovers are removed on launch.").font(.system(size: 11)).foregroundColor(.secondary)
                    if !model.hasKey { Button("Add API key in Voice & AI") { model.tab = "Voice & AI" }.buttonStyle(.plain).foregroundColor(green) }
                }
                Toggle("Clean up filler words and punctuation with AI", isOn: setting(\.cleanup)).disabled(!model.hasKey)
                Text("Optional: sends only your transcript to OpenAI. Keeps the original so you can compare. Review names, numbers, and meaning before sending.").font(.system(size: 11)).foregroundColor(.secondary)
                TextField("Vocabulary, separated by commas", text: setting(\.vocabulary)).textFieldStyle(.roundedBorder)
            }
            card {
                HStack { Label(controller.phase, systemImage: controller.recording ? "mic.fill" : "text.bubble").font(.system(size: 15, weight: .semibold)).foregroundColor(green); Spacer(); if controller.busy { Text("\(controller.seconds)s").monospacedDigit() } }
                if !controller.timing.isEmpty { Text(controller.timing).font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary) }
                Text(controller.message).font(.system(size: 12)).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button(controller.recording ? "Finish recording" : "Try dictation here") { if controller.recording { controller.finish() } else { controller.begin(inApp: true) } }.buttonStyle(DoclinButton()).disabled(controller.busy && !controller.recording)
                    if controller.busy { Button("Cancel") { controller.cancel() } }
                }
                if !controller.partial.isEmpty && controller.busy { Text(controller.partial).font(.system(size: 13)).foregroundColor(.secondary).lineLimit(4) }
                TextEditor(text: $controller.transcript).font(.system(size: 14)).frame(minHeight: 110).padding(6).background(Color.gray.opacity(0.06), in: RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.15))).accessibilityLabel("Dictation transcript")
                HStack {
                    Button("Copy transcript") { controller.copyTranscript() }.disabled(controller.transcript.isEmpty)
                    if !controller.originalTranscript.isEmpty && controller.transcript != controller.originalTranscript { Button("Restore original") { controller.transcript = controller.originalTranscript } }
                    Spacer()
                    Button("Clear") { controller.clearTranscript() }.disabled(controller.busy)
                }
                Text("The last transcript stays in memory until cleared or you quit. There is no dictation history on disk.").font(.system(size: 10)).foregroundColor(.secondary)
            }
        }.onAppear { controller.refreshPermissions() }
    }
    private func permission(_ title: String, detail: String, granted: Bool, action: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle").foregroundColor(granted ? green : .secondary)
            VStack(alignment: .leading, spacing: 3) { Text(title).font(.system(size: 12, weight: .medium)); Text(detail).font(.system(size: 10)).foregroundColor(.secondary) }
            Spacer()
            if granted { Text("Allowed").font(.system(size: 11)).foregroundColor(green) } else { Button("Allow…", action: action).font(.system(size: 11)) }
        }
    }
    private func setting<T>(_ key: WritableKeyPath<DictationPreferences, T>) -> Binding<T> {
        Binding(get: { controller.settings[keyPath: key] }, set: { controller.settings[keyPath: key] = $0; controller.saveSettings() })
    }
    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 15, content: content).padding(22).frame(maxWidth: .infinity, alignment: .leading).background(Color.white, in: RoundedRectangle(cornerRadius: 13))
    }
}
