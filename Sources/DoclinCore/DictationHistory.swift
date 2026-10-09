import Foundation

public struct DictationRecord: Identifiable, Equatable {
    public let id: UUID
    public var text: String
    public let original: String
    public let destination: String
    public let timestamp: Date
    public var state: String
}

// Session-only text history. Never encode or write dictated content to disk.
public struct DictationHistory {
    public private(set) var entries: [DictationRecord] = []
    public init() {}
    public mutating func record(id: UUID, text: String, original: String, destination: String, timestamp: Date) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !entries.contains(where: { $0.id == id }) else { return }
        entries.insert(DictationRecord(id: id, text: text, original: original, destination: destination, timestamp: timestamp, state: "Text ready"), at: 0)
        entries = Array(entries.prefix(30))
    }
    public mutating func setState(_ id: UUID, state: String) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].state = state
    }
    public mutating func applyResult(_ id: UUID, text: String) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].text = text
    }
    public mutating func edit(_ id: UUID, text: String) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].text = text
        entries[index].state = text == entries[index].original ? "Original text" : "Edited"
    }
    public mutating func clear() { entries.removeAll() }
}
