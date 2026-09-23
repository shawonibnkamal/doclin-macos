import Foundation

/// Recognition hypotheses replace the active utterance, never completed utterances.
/// Metadata marks an utterance boundary even when the overall task is not final.
public struct TranscriptBuffer {
    private var completed: [String] = []
    private var active = ""
    private var boundary = false
    private var firstStart: TimeInterval?
    private var utteranceStart: TimeInterval?
    public init() {}
    public var text: String { (completed + [active]).filter { !$0.isEmpty }.joined(separator: " ") }
    public mutating func update(_ incoming: String, completedUtterance: Bool, start: TimeInterval?) -> String {
        let value = incoming.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return text }
        let laterUtterance = start.map { next in utteranceStart.map { next > $0 + 0.05 } ?? false } ?? false
        // A cumulative callback may include utterances we already committed.
        // Rebase the whole buffer instead of prepending those utterances twice.
        let prefix = completed.joined(separator: " ")
        let knownCumulativeStart = completedUtterance && start != nil && firstStart != nil && abs(start! - firstStart!) < 0.05
        if firstStart == nil, let start { firstStart = start }
        if !prefix.isEmpty, !laterUtterance,
           value.lowercased().hasPrefix(prefix.lowercased()),
           value.lowercased().hasPrefix(text.lowercased()) || knownCumulativeStart {
            completed = []; active = value; boundary = completedUtterance
            if let start { utteranceStart = start }
            return text
        }
        if boundary && !active.isEmpty {
            // Identical metadata-less updates are ambiguous, not proof of a repeated phrase.
            // A later timestamp can confirm a genuine repetition on a subsequent callback.
            if !laterUtterance && value == active { return text }
            if !laterUtterance && !completedUtterance && active.hasPrefix(value) { return text }
            // Some OS versions keep a cumulative hypothesis. Keep it in one active chunk.
            let cumulative = value.lowercased().hasPrefix(active.lowercased()) && value.count > active.count
            if laterUtterance || (!completedUtterance && !cumulative) {
                completed.append(active); active = ""; utteranceStart = nil; boundary = false
            }
        }
        active = value
        if let start { utteranceStart = start }
        boundary = completedUtterance
        return text
    }
}
