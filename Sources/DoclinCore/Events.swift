import Foundation

public struct AgentEvent: Codable, Equatable {
    public var source: String
    public var session: String
    public var turn: String
    public var kind: String
    public var text: String
    public var project: String
    public var prompt: String
    public var timestamp: Date
    public var key: String { source + ":" + session }
    public var id: String { key + ":" + turn + ":" + kind }
    public init(source: String, session: String, turn: String = UUID().uuidString, kind: String = "complete", text: String = "", project: String = "", prompt: String = "", timestamp: Date = Date()) {
        self.source = source; self.session = session; self.turn = turn; self.kind = kind; self.text = text; self.project = project; self.prompt = prompt; self.timestamp = timestamp
    }
}

public enum SpeechText {
    public static func clean(_ text: String) -> String {
        var s = text
        for (pattern, replacement) in [
            ("(?s)```.*?```", " "),
            ("<oai-mem-citation>[\\s\\S]*?</oai-mem-citation>", " "),
            ("::[a-z-]+\\{[^}]*\\}", " "),
            ("!?\\[([^\\]]*)\\]\\([^)]*\\)", "$1"),
            ("https?://\\S+", " "),
            ("(?m)^\\s*[#>*•-]+\\s*", ""),
            ("[`*_~]", ""),
            ("[\\r\\n\\t]+", " "),
            ("\\s+", " ")
        ] { s = s.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression) }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    public static func limited(_ text: String, words: Int = 20) -> String {
        let s = clean(text)
        let parts = s.split(whereSeparator: { $0.isWhitespace })
        return parts.count <= words ? s : parts.prefix(words).joined(separator: " ").trimmingCharacters(in: CharacterSet(charactersIn: ",:;.-")) + "…"
    }
    public static func excerpt(_ event: AgentEvent, words: Int) -> String {
        let body = clean(event.text)
        if body.isEmpty { return limited("Response ready.", words: words) }
        // Extract, never classify a completed turn as successful work.
        let first = body.components(separatedBy: ". ").first ?? body
        return limited(first, words: words)
    }
}

public struct QueuePolicy {
    public private(set) var pending: [AgentEvent] = []
    private var seen: [String: Date] = [:]
    private var latestStart: [String: Date] = [:]
    public var lifetime: TimeInterval = 30
    public init() {}
    public mutating func receive(_ event: AgentEvent, now: Date = Date()) -> Bool {
        seen = seen.filter { now.timeIntervalSince($0.value) < 3600 }
        latestStart = latestStart.filter { now.timeIntervalSince($0.value) < 86400 }
        pending.removeAll { now.timeIntervalSince($0.timestamp) > lifetime }
        guard seen[event.id] == nil else { return false }
        seen[event.id] = now
        if event.kind == "start" {
            latestStart[event.key] = max(latestStart[event.key] ?? .distantPast, event.timestamp)
            pending.removeAll { $0.key == event.key && $0.timestamp <= event.timestamp }
            return true
        }
        guard event.kind == "complete", now.timeIntervalSince(event.timestamp) <= lifetime,
              event.timestamp >= (latestStart[event.key] ?? .distantPast) else { return false }
        pending.removeAll { $0.key == event.key }
        pending.append(event)
        pending = Array(pending.suffix(10))
        return true
    }
    public mutating func next(now: Date = Date()) -> AgentEvent? {
        pending.removeAll { now.timeIntervalSince($0.timestamp) > lifetime }
        return pending.isEmpty ? nil : pending.removeFirst()
    }
    public mutating func clear() { pending.removeAll() }
}

/// Deliberately only parses lifecycle messages, not tool outputs or reasoning.
public final class CodexParser {
    public var session = ""
    public var project = ""
    public var prompt = ""
    public var isSubagent = false
    private let formatter = ISO8601DateFormatter()
    public init() { formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds] }
    public func parse(_ data: Data) -> AgentEvent? {
        guard let d = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let p = d["payload"] as? [String: Any], let type = d["type"] as? String else { return nil }
        if type == "session_meta" {
            session = p["id"] as? String ?? p["session_id"] as? String ?? session
            project = URL(fileURLWithPath: p["cwd"] as? String ?? "").lastPathComponent
            let source = p["source"]
            isSubagent = p["thread_source"] as? String == "subagent" || (source as? [String: Any])?["subagent"] != nil
            return nil
        }
        if type == "turn_context", let cwd = p["cwd"] as? String { project = URL(fileURLWithPath: cwd).lastPathComponent }
        if type == "response_item", p["role"] as? String == "user", let content = p["content"] as? [[String: Any]] {
            let text = content.compactMap { $0["text"] as? String }.joined(separator: " ")
            if !text.hasPrefix("<environment_context>") && !text.hasPrefix("<permissions") && !text.hasPrefix("<system") { prompt = String(text.prefix(600)) }
        }
        guard !isSubagent, !session.isEmpty, type == "event_msg" else { return nil }
        let eventType = p["type"] as? String ?? ""
        guard ["task_started", "task_complete", "user_message"].contains(eventType) else { return nil }
        let timeText = d["timestamp"] as? String ?? ""
        let timestamp = formatter.date(from: timeText) ?? ISO8601DateFormatter().date(from: timeText)
        guard let timestamp else { return nil } // Unknown timestamps must not replay old work.
        if eventType == "user_message" { prompt = String((p["message"] as? String ?? "").prefix(600)) }
        return AgentEvent(source: "Codex", session: session, turn: p["turn_id"] as? String ?? timeText,
                          kind: eventType == "task_complete" ? "complete" : "start",
                          text: String((p["last_agent_message"] as? String ?? "").prefix(12000)), project: project,
                          prompt: prompt, timestamp: timestamp)
    }
}

public enum HookParser {
    public static func parse(_ data: Data, source: String, now: Date = Date()) -> AgentEvent? {
        guard let d = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        if source == "codex" {
            guard d["type"] as? String == "agent-turn-complete", let session = d["thread-id"] as? String else { return nil }
            return AgentEvent(source: "Codex", session: session, turn: d["turn-id"] as? String ?? UUID().uuidString,
                              text: String((d["last-assistant-message"] as? String ?? "").prefix(12000)),
                              project: URL(fileURLWithPath: d["cwd"] as? String ?? "").lastPathComponent, timestamp: now)
        }
        guard let session = d["session_id"] as? String, let hook = d["hook_event_name"] as? String,
              hook == "Stop" || hook == "UserPromptSubmit", d["agent_id"] == nil else { return nil }
        return AgentEvent(source: "Claude", session: session, kind: hook == "Stop" ? "complete" : "start",
                          text: String((d["last_assistant_message"] as? String ?? "").prefix(12000)),
                          project: URL(fileURLWithPath: d["cwd"] as? String ?? "").lastPathComponent,
                          prompt: String((d["prompt"] as? String ?? "").prefix(600)), timestamp: now)
    }
}
