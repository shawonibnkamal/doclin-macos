import SwiftUI
import AppKit

/// A nonactivating panel keeps the insertion destination focused.
final class DictationPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
final class DictationHUDHost<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
enum DictationIndicatorState { case off, setup, ready, listening, processing, success, retained, error, canceled }

struct DictationHUD: View {
    @ObservedObject var controller: DictationController
    // Match the cyan accent used by Doclin's dark website and branding (#5cdaff).
    private let accent = Color(red: 92 / 255, green: 218 / 255, blue: 1)
    private var state: DictationIndicatorState { controller.indicatorState }
    private var warning: Bool { state == .setup || state == .error }
    var body: some View {
        HStack(spacing: 10) {
            Button { controller.indicatorAction() } label: {
                if state == .processing { ProgressView().controlSize(.mini).frame(width: 24, height: 24) }
                else { Image(systemName: symbol).font(.system(size: 11, weight: .semibold)).frame(width: 24, height: 24).contentShape(Circle()) }
            }.buttonStyle(.plain).disabled(state == .processing)
                .foregroundColor(warning ? .orange : accent)
                .accessibilityLabel(state == .listening ? "Finish dictation" : warning ? "Open dictation setup" : "Start dictation")
                .help(controller.indicatorTitle)
            if state == .listening {
                HStack(spacing: 3) {
                    ForEach(0..<7) { index in
                        Capsule().fill(accent).frame(width: 3, height: max(3, CGFloat(controller.indicatorLevel) * 19 * (0.4 + 0.6 * abs(sin(Double(index) * 1.7)))))
                    }
                }.frame(width: 39, height: 20).animation(.easeOut(duration: 0.1), value: controller.indicatorLevel)
                    .accessibilityLabel("Microphone level").accessibilityValue("\(Int(controller.indicatorLevel * 100)) percent")
                Text(controller.indicatorStarting ? "…" : String(format: "%d:%02d", controller.seconds / 60, controller.seconds % 60))
                    .font(.system(size: 10, design: .monospaced)).foregroundColor(.white.opacity(0.7)).frame(width: 32)
            } else {
                Button(state == .retained ? "Copy text" : warning ? "Set up" : state == .processing ? "Working…" : "Dictate") {
                    if state == .retained { controller.copyTranscript() } else { controller.indicatorAction() }
                }.buttonStyle(.plain).font(.system(size: 11)).disabled(state == .processing).lineLimit(1).frame(maxWidth: .infinity)
            }
            Spacer(minLength: 0)
            Button { controller.dismissIndicator() } label: {
                Image(systemName: "xmark").font(.system(size: 9, weight: .semibold)).frame(width: 22, height: 24).contentShape(Rectangle())
            }.buttonStyle(.plain).foregroundColor(.white.opacity(0.45))
                .accessibilityLabel(controller.busy ? "Cancel dictation" : "Hide dictation indicator")
        }
        .padding(.horizontal, 10).frame(width: controller.indicatorWidth, height: controller.indicatorHeight)
        .background(Color(red: 13 / 255, green: 20 / 255, blue: 34 / 255), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.12)).allowsHitTesting(false))
        .foregroundColor(.white).preferredColorScheme(.dark)
        .help(controller.indicatorPreview ? "Preview only · microphone is off" : controller.indicatorSubtitle)
    }
    private var symbol: String {
        switch state {
        case .listening: return "stop.fill"
        case .success: return "checkmark"
        case .retained: return "doc.text"
        case .setup, .error: return "exclamationmark"
        default: return "mic.fill"
        }
    }
}
