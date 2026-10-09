import SwiftUI
import DoclinCore

struct DictationView: View {
    @ObservedObject var controller: DictationController
    @ObservedObject var model: AppModel
    @State private var editing: UUID?
    @State private var draft = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            DoclinCard {
                HStack {
                    Text(controller.settings.enabled ? controller.busy ? controller.phase : "Hold \(controller.shortcutLabel) to dictate" : "Dictation paused")
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Toggle("Enabled", isOn: Binding(get: { controller.settings.enabled }, set: { controller.settings.enabled = $0; controller.saveSettings() }))
                        .toggleStyle(.switch).controlSize(.small)
                    if controller.busy { Text("\(controller.seconds)s").font(.system(size: 12)).monospacedDigit() }
                }
                HStack {
                    Label(controller.settings.provider == "local" ? "On-device speech" : "Audio sent to OpenAI", systemImage: controller.settings.provider == "local" ? "lock" : "cloud")
                    if controller.settings.cleanup { Text("· OpenAI text cleanup") }
                }.font(.system(size: 11)).foregroundColor(.secondary)
                if controller.settings.enabled || controller.busy {
                    HStack {
                        Button(controller.recording ? "Finish" : "Dictate here") {
                            if controller.recording { controller.finish() } else { controller.begin(inApp: true) }
                        }.buttonStyle(DoclinButton()).disabled(!controller.settings.enabled || (controller.busy && !controller.recording))
                        if controller.busy { Button("Cancel") { controller.cancel() } }
                    }
                }
                if controller.busy && !controller.partial.isEmpty {
                    Text(controller.partial).font(.system(size: 14)).foregroundColor(.secondary).accessibilityLabel("Live transcript")
                }
                if controller.message != "Hold the shortcut in a text field to dictate." {
                    Text(controller.message).font(.system(size: 11)).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            DoclinHistoryCard(title: "Recent dictations", emptyMessage: "Your dictated text will appear here.", isEmpty: controller.history.entries.isEmpty, canClear: !controller.busy, clear: { controller.clearHistory(); editing = nil }) {
                ForEach(controller.history.entries) { row in
                    VStack(alignment: .leading, spacing: 8) {
                        DoclinHistoryMetadata(source: row.destination, state: row.state, timestamp: row.timestamp)
                        if editing == row.id {
                            TextEditor(text: $draft).font(.system(size: 14)).frame(height: 90).accessibilityLabel("Edit dictation")
                            HStack {
                                Button("Save") { guard !controller.busy else { return }; controller.editHistory(row.id, text: draft); editing = nil }.disabled(controller.busy)
                                Button("Cancel") { editing = nil }
                            }
                        } else {
                            Text(row.text).font(.system(size: 14)).textSelection(.enabled)
                            HStack {
                                Button("Copy") { controller.copyText(row.text) }.disabled(row.text.isEmpty)
                                Button("Edit") { draft = row.text; editing = row.id }.disabled(controller.busy)
                                if row.text != row.original {
                                    Button("Restore original") { controller.editHistory(row.id, text: row.original) }.disabled(controller.busy)
                                }
                            }
                        }
                    }.padding(.vertical, 12)
                    Divider()
                }
            }
        }
    }
}
