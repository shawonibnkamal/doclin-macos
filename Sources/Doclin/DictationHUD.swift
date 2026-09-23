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
    private let mint = Color(red: 0.66, green: 0.94, blue: 0.78)
    private var state: DictationIndicatorState { controller.indicatorState }
    private var active: Bool { state == .listening || state == .processing }
    private var warning: Bool { state == .setup || state == .error }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Button { controller.indicatorAction() } label: {
                    ZStack {
                        Circle().fill(warning ? Color.orange.opacity(0.2) : mint.opacity(0.15)).frame(width: 38, height: 38)
                        if state == .processing { ProgressView().controlSize(.small).tint(mint) }
                        else { Image(systemName: symbol).font(.system(size: 16, weight: .semibold)).foregroundColor(warning ? .orange : mint) }
                    }
                }.buttonStyle(.plain).disabled(state == .processing)
                    .accessibilityLabel(state == .listening ? "Finish dictation" : warning ? "Open dictation setup" : "Start dictation")
                VStack(alignment: .leading, spacing: 4) {
                    Text(controller.indicatorTitle).font(.system(size: 13, weight: .semibold))
                    Text(controller.indicatorSubtitle).font(.system(size: 10)).foregroundColor(.white.opacity(0.62)).lineLimit(2)
                }
                Spacer(minLength: 4)
                if state == .listening {
                    Text(String(format: "%d:%02d", controller.seconds / 60, controller.seconds % 60)).font(.system(size: 11, design: .monospaced)).foregroundColor(mint)
                }
                if warning {
                    Button("Set up") { controller.openSettings() }.font(.system(size: 11, weight: .medium)).buttonStyle(.plain).foregroundColor(.orange)
                }
                Button { controller.dismissIndicator() } label: {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .semibold)).padding(7).contentShape(Rectangle())
                }.buttonStyle(.plain).foregroundColor(.white.opacity(0.5)).accessibilityLabel(active ? "Cancel dictation" : "Hide dictation indicator")
            }
            if state == .listening {
                HStack(spacing: 4) {
                    ForEach(0..<33) { index in
                        let shape = 0.35 + 0.65 * abs(sin(Double(index) * 1.7))
                        Capsule().fill(mint.opacity(0.9)).frame(width: 5, height: max(3, CGFloat(controller.indicatorLevel) * 27 * shape))
                    }
                }.frame(maxWidth: .infinity).frame(height: 28).animation(.easeOut(duration: 0.10), value: controller.indicatorLevel)
                    .accessibilityLabel("Microphone level").accessibilityValue("\(Int(controller.indicatorLevel * 100)) percent")
                Text(controller.indicatorPreview ? "Preview only · microphone is off" : controller.settings.provider == "cloud" ? "Your words will appear after you finish." : controller.partial.isEmpty ? (controller.seconds >= 4 ? "No words yet. Check that your mic can hear you." : "Listening for your voice…") : String(controller.partial.suffix(160)))
                    .font(.system(size: 12)).foregroundColor(.white.opacity(0.85)).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
            } else if state == .processing {
                Text(controller.indicatorPreview ? "Preview only · microphone is off" : "Your recording has stopped. Getting your words ready…")
                    .font(.system(size: 12)).foregroundColor(.white.opacity(0.75)).lineLimit(2)
            } else if state == .retained {
                HStack {
                    Text(controller.indicatorPreview ? "Preview only · nothing was inserted" : String(controller.transcript.prefix(100))).font(.system(size: 12)).lineLimit(2)
                    Spacer()
                    if !controller.indicatorPreview { Button("Copy") { controller.copyTranscript() }.buttonStyle(.plain).foregroundColor(mint).font(.system(size: 12, weight: .semibold)) }
                }
            } else if state == .error {
                Text(controller.message).font(.system(size: 11)).foregroundColor(.white.opacity(0.75)).lineLimit(3)
            }
        }
        .padding(16).frame(width: 380, height: controller.indicatorHeight, alignment: .center)
        .background(Color(red: 0.075, green: 0.09, blue: 0.10), in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.14)).allowsHitTesting(false))
        .foregroundColor(.white).preferredColorScheme(.dark)
    }
    private var symbol: String {
        switch state {
        case .listening: return "stop.fill"
        case .success: return "checkmark"
        case .retained: return "doc.text"
        case .setup, .error: return "exclamationmark"
        case .canceled: return "xmark"
        default: return "mic.fill"
        }
    }
}
