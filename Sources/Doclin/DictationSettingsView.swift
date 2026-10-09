import SwiftUI
import DoclinCore

struct DictationSettingsView: View {
    @ObservedObject var controller: DictationController
    @ObservedObject var model: AppModel
    private var needsSetup: Bool {
        !controller.microphoneGranted ||
        ((controller.settings.shortcut == "right-command" || controller.settings.autoInsert) && !controller.accessibilityGranted) ||
        (controller.settings.provider == "local" && !controller.modernReady && !controller.speechGranted)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if controller.settings.enabled && needsSetup {
                DoclinSettingNote("Finish permission setup under Troubleshooting before dictating.")
                Button("Open troubleshooting") { model.tab = "Troubleshooting" }
            }
            DoclinSettingsGroup {
                DoclinSettingRow("Shortcut") {
                    Picker("Shortcut", selection: setting(\.shortcut)) { ForEach(DictationHotkey.choices, id: \.0) { Text($0.1).tag($0.0) } }.labelsHidden()
                }
                DoclinSettingRow("Language") {
                    Picker("Language", selection: setting(\.locale)) {
                        ForEach([("en-US", "English (US)"), ("en-CA", "English (Canada)"), ("en-GB", "English (UK)"), ("fr-FR", "French"), ("es-ES", "Spanish"), ("de-DE", "German"), ("pt-BR", "Portuguese"), ("bn-BD", "Bengali")], id: \.0) { Text($0.1).tag($0.0) }
                    }.labelsHidden()
                }
                DoclinSettingRow("Auto insert") { Toggle("Insert at the original cursor", isOn: setting(\.autoInsert)).labelsHidden().toggleStyle(.switch).controlSize(.small) }
                DoclinSettingRow("Clipboard paste") { Toggle("Use clipboard paste", isOn: setting(\.clipboardFallback)).labelsHidden().toggleStyle(.switch).controlSize(.small) }
                DoclinSettingRow("Start sound") { Toggle("Sound when recording starts", isOn: Binding(get: { controller.startSoundEnabled }, set: { controller.setStartSound($0) })).labelsHidden().toggleStyle(.switch).controlSize(.small) }
                DoclinSettingRow("Custom words") { TextField("Words, separated by commas", text: setting(\.vocabulary)).textFieldStyle(.roundedBorder) }
                DoclinSettingRow("Processing") {
                    Picker("Speech processing", selection: setting(\.provider)) { Text("On this Mac").tag("local"); Text("OpenAI").tag("cloud") }.labelsHidden()
                }
                DoclinSettingRow("AI cleanup") { Toggle("Clean up text with OpenAI", isOn: setting(\.cleanup)).labelsHidden().toggleStyle(.switch).controlSize(.small).disabled(!model.hasKey) }
            }
            DoclinSettingNote("Clipboard paste leaves the transcript on your clipboard. If you switch fields or type during processing, text stays in Doclin. Doclin never presses Send.")
            if controller.settings.provider == "cloud" {
                DoclinSettingNote("OpenAI processing sends your recording and custom words to OpenAI. API usage may incur charges.")
                if !model.hasKey { Button("Add API key") { model.tab = "Cloud" } }
            } else {
                DoclinSettingNote(controller.engineMessage.isEmpty ? controller.recognitionEngine : controller.engineMessage)
            }
            DoclinSettingNote("AI cleanup sends the transcript to OpenAI. Original words remain available to restore.")
        }.onAppear { controller.refreshPermissions() }
    }
    private func setting<T>(_ key: WritableKeyPath<DictationPreferences, T>) -> Binding<T> {
        Binding(get: { controller.settings[keyPath: key] }, set: { controller.settings[keyPath: key] = $0; controller.saveSettings() })
    }
}

struct DictationTroubleshootingView: View {
    @ObservedObject var controller: DictationController
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DoclinSettingsGroup {
                permission("Microphone", granted: controller.microphoneGranted, action: controller.requestMicrophone)
                permission("Accessibility", granted: controller.accessibilityGranted, action: controller.openAccessibility)
                if controller.settings.provider == "local" && !controller.modernReady {
                    permission("Speech", granted: controller.speechGranted, action: controller.requestSpeech)
                }
                DoclinSettingRow("Refresh status") { Button("Refresh permissions") { controller.refreshPermissions() } }
                DoclinSettingRow("Microphone") { Button("System Settings") { controller.openMicrophoneSettings() } }
                DoclinSettingRow("Accessibility") { Button("System Settings") { controller.openAccessibility() } }
                if controller.settings.provider == "local" && !controller.modernReady {
                    DoclinSettingRow("Speech") { Button("System Settings") { controller.openSpeechSettings() } }
                }
                DoclinSettingRow("Insertion test") { Button("Test in 8 seconds") { controller.testInsertion() }.disabled(controller.busy) }
                DoclinSettingRow("Recording pill") { Button("Preview pill") { controller.previewIndicator() }.disabled(controller.busy) }
            }
            DoclinSettingNote("Previously denied? Enable Doclin in System Settings. The insertion test uses no microphone; focus an empty field in another app. Without Accessibility, use Dictate here and copy.")
            if !controller.timing.isEmpty { DoclinSettingNote(controller.timing) }
            DoclinSettingNote("Transcripts stay in memory until cleared or quit. Local audio is not saved by Doclin.")
        }.onAppear { controller.refreshPermissions() }
    }
    private func permission(_ title: String, granted: Bool, action: @escaping () -> Void) -> some View {
        DoclinSettingRow(title) {
            HStack {
                Text(granted ? "Allowed" : "Needed").font(.system(size: 11)).foregroundColor(.secondary)
                if !granted { Button("Allow…", action: action) }
            }
        }
    }
}
