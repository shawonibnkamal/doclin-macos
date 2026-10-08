import Foundation

public enum LocalVoiceChoice {
    public static let choices: [(key: String, name: String, speaker: Int)] = [
        ("kokoro:2", "Bella · American", 2),
        ("kokoro:3", "Heart · American (previous voice)", 3),
        ("kokoro:16", "Michael · American", 16),
        ("kokoro:22", "Isabella · British", 22)
    ]
    public static func speaker(for key: String) -> Int? { key.isEmpty ? 2 : choices.first { $0.key == key }?.speaker }
    public static func spoken(_ text: String) -> String {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = value.last, last.isLetter || last.isNumber else { return value }
        return value + "."
    }
}
