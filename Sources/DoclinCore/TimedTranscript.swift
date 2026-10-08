import Foundation

/// SpeechAnalyzer results describe audio ranges, not cumulative transcripts.
/// Keep confirmed ranges across pauses; only replace the provisional range.
public struct TimedTranscript {
    private struct Segment { var start: Double; var end: Double; var text: String; var final: Bool }
    private var segments: [Segment] = []
    public init() {}
    public var text: String { segments.sorted { $0.start < $1.start }.map(\.text).joined().trimmingCharacters(in: .whitespacesAndNewlines) }
    public mutating func update(_ text: String, start: Double, end: Double, final: Bool) -> String {
        guard start.isFinite, end.isFinite, end > start else { return self.text }
        let overlaps: (Segment) -> Bool = { $0.start < end - 0.001 && $0.end > start + 0.001 }
        // A late provisional callback cannot overwrite already confirmed words.
        if !final && segments.contains(where: { $0.final && overlaps($0) }) { return self.text }
        segments.removeAll(where: overlaps)
        if !text.isEmpty { segments.append(Segment(start: start, end: end, text: text, final: final)) }
        return self.text
    }
}
