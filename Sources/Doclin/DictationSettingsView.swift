import SwiftUI
import DoclinCore

struct DictationSettingsView: View {
    @ObservedObject var controller: DictationController
    @ObservedObject var model: AppModel
    private let accent = Color(red: 0.255, green: 0.424, blue: 0.78)
    private var needsAccessibility: Bool { controller.settings.shortcut == "right-command" || controller.settings.autoInsert }
    private var needsSetup: Bool {
        !controller.microphoneGranted || (needsAccessibility && !controller.accessibilityGranted) ||
        (controller.settings.provider == "local" && !controller.modernReady && !controller.speechGranted)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle("Enable dictation", isOn: setting(\.enabled)).toggleStyle(.switch).controlSize(.small)
            if needsSetup && controller.settings.enabled {
                VStack(alignment: .leading, spacing: 10) {
                    HStack { Text("Finish setup").font(.system(size: 15, weight: .semibold)); Spacer(); Button("Refresh") { controller.refreshPermissions() } }
                    if !controller.microphoneGranted { permission("Microphone") { controller.requestMicrophone() } }
                    if controller.settings.provider == "local" && !controller.modernReady && !controller.speechGranted { permission("Speech Recognition") { controller.requestSpeech() } }
                    if needsAccessibility && !controller.accessibilityGranted { permission("Accessibility · shortcut and insertion") { controller.openAccessibility() } }
                    HStack {
                        if !controller.microphoneGranted { Button("Microphone settings") { controller.openMicrophoneSettings() } }
                        if controller.settings.provider == "local" && !controller.modernReady && !controller.speechGranted { Button("Speech settings") { controller.openSpeechSettings() } }
                    }.font(.system(size: 11))
                    Text("Previously denied? Enable Doclin in System Settings. Without Accessibility, use Dictate here and copy.").font(.system(size: 11)).foregroundColor(.secondary)
                }.padding(14).background(accent.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
            }
            VStack(alignment: .leading, spacing: 14) {
                Picker("Shortcut", selection: setting(\.shortcut)) { ForEach(DictationHotkey.choices, id: \.0) { Text($0.1).tag($0.0) } }
                Picker("Language", selection: setting(\.locale)) {
                    ForEach([("en-US", "English (US)"), ("en-CA", "English (Canada)"), ("en-GB", "English (UK)"), ("fr-FR", "French"), ("es-ES", "Spanish"), ("de-DE", "German"), ("pt-BR", "Portuguese"), ("bn-BD", "Bengali")], id: \.0) { Text($0.1).tag($0.0) }
                }
                Toggle("Insert at the original cursor", isOn: setting(\.autoInsert))
                Toggle("Use clipboard paste", isOn: setting(\.clipboardFallback))
                Text("Clipboard paste leaves the transcript on your clipboard. If you switch fields or type during processing, text stays here. Doclin never presses Send.").font(.system(size: 11)).foregroundColor(.secondary)
                Toggle("Sound when recording starts", isOn: Binding(get: { controller.startSoundEnabled }, set: { controller.setStartSound($0) }))
                TextField("Custom words, separated by commas", text: setting(\.vocabulary)).textFieldStyle(.roundedBorder)
                Divider()
                Picker("Speech processing", selection: setting(\.provider)) { Text("On this Mac").tag("local"); Text("OpenAI").tag("cloud") }
                if controller.settings.provider == "cloud" {
                    Text("Sends your recording and custom words to OpenAI. Uses your API key and may incur charges.").font(.system(size: 12)).foregroundColor(.secondary)
                    if !model.hasKey { Button("Add API key") { model.tab = "Voice & AI" } }
                } else {
                    Text(controller.engineMessage.isEmpty ? controller.recognitionEngine : controller.engineMessage).font(.system(size: 11)).foregroundColor(.secondary)
                }
                Toggle("Clean up text with OpenAI", isOn: setting(\.cleanup)).disabled(!model.hasKey)
                Text("Cleanup sends the transcript to OpenAI. The original is kept so you can compare.").font(.system(size: 11)).foregroundColor(.secondary)
                DisclosureGroup("Troubleshooting") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Microphone: \(controller.microphoneGranted ? "allowed" : "needed") · Accessibility: \(controller.accessibilityGranted ? "allowed" : "needed")").font(.system(size: 11))
                        HStack {
                            Button("Refresh permissions") { controller.refreshPermissions() }
                            Button("Microphone settings") { controller.openMicrophoneSettings() }
                            Button("Accessibility settings") { controller.openAccessibility() }
                        }
                        Button("Test insertion in another app (8 seconds)") { controller.testInsertion() }.disabled(controller.busy)
                        Button("Preview recording pill") { controller.previewIndicator() }.disabled(controller.busy)
                        if !controller.timing.isEmpty { Text(controller.timing).font(.system(size: 11, design: .monospaced)) }
                        Text("Transcript is kept in memory until cleared or quit. Local audio is not saved by Doclin.").font(.system(size: 11)).foregroundColor(.secondary)
                    }.padding(.top, 8)
                }
            }
        }.onAppear { controller.refreshPermissions() }
    }
    private func permission(_ title: String, action: @escaping () -> Void) -> some View {
        HStack { Text(title).font(.system(size: 12)); Spacer(); Button("Allow…", action: action) }
    }
    private func setting<T>(_ key: WritableKeyPath<DictationPreferences, T>) -> Binding<T> {
        Binding(get: { controller.settings[keyPath: key] }, set: { controller.settings[keyPath: key] = $0; controller.saveSettings() })
    }
}
