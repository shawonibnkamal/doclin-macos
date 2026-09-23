import Foundation
import Darwin

public enum DoclinPaths {
    public static var support: URL {
        if let override = ProcessInfo.processInfo.environment["DOCLIN_SUPPORT_DIR"] { return URL(fileURLWithPath: override) }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Doclin")
    }
    public static var inbox: URL { support.appendingPathComponent("inbox") }
    public static func prepare() throws {
        try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: support.path)
    }
    public static var heartbeat: URL { support.appendingPathComponent("heartbeat") }
    public static func beat() {
        try? prepare()
        try? Data(String(ProcessInfo.processInfo.processIdentifier).utf8).write(to: heartbeat, options: .atomic)
    }
    public static func isRunning(now: Date = Date()) -> Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: heartbeat.path),
              let modified = attributes[.modificationDate] as? Date, now.timeIntervalSince(modified) < 5,
              let data = try? Data(contentsOf: heartbeat), let text = String(data: data, encoding: .utf8),
              let pid = Int32(text), pid > 0 else { return false }
        return kill(pid, 0) == 0
    }
    public static func cleanInbox(all: Bool = false) {
        guard let files = try? FileManager.default.contentsOfDirectory(at: inbox, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        for file in files where file.pathExtension == "json" {
            let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            if all || Date().timeIntervalSince(modified) > 60 { try? FileManager.default.removeItem(at: file) }
        }
    }
    public static func spool(_ event: AgentEvent) throws {
        guard isRunning() else { cleanInbox(all: true); return }
        let preferences = Preferences.load()
        guard !preferences.muted, preferences.allows(event) else { return }
        try prepare()
        cleanInbox()
        let dest = inbox.appendingPathComponent(UUID().uuidString + ".json")
        let data = try JSONEncoder().encode(event)
        try data.write(to: dest, options: [.atomic])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: dest.path)
    }
}

public struct Preferences: Codable {
    public var muted = false
    public var codexEnabled = true
    public var claudeEnabled = true
    public var useAI = false
    public var aiVoice = false
    public var voice = "coral"
    public var systemVoice = ""
    public var volume: Double = 0.55
    public var rate: Double = 1.0
    public var wordLimit = 15
    public var expiry: Double = 30
    public var excludedProjects = ""
    public var codexHome = "~/.codex"
    public init() {}
    public static func load() -> Preferences {
        guard let d = try? Data(contentsOf: DoclinPaths.support.appendingPathComponent("preferences.json")), let p = try? JSONDecoder().decode(Preferences.self, from: d) else { return Preferences() }
        var safe = p
        safe.wordLimit = min(25, max(15, p.wordLimit))
        safe.volume = min(1, max(0, p.volume))
        safe.rate = min(1.5, max(0.8, p.rate))
        safe.expiry = min(60, max(15, p.expiry))
        return safe
    }
    public func save() throws {
        try DoclinPaths.prepare()
        try JSONEncoder().encode(self).write(to: DoclinPaths.support.appendingPathComponent("preferences.json"), options: .atomic)
    }
    public func allows(_ event: AgentEvent) -> Bool {
        if event.source == "Codex" && !codexEnabled { return false }
        if event.source == "Claude" && !claudeEnabled { return false }
        let excluded = excludedProjects.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        return !excluded.contains(event.project.lowercased())
    }
}

public enum ClaudeIntegration {
    public static let marker = "--doclin-hook"
    public static func installed(at settings: URL) -> Bool {
        guard let data = try? Data(contentsOf: settings), let text = String(data: data, encoding: .utf8) else { return false }
        return text.contains(marker)
    }
    public static func shellQuote(_ s: String) -> String { "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'" }
    /// Preserve every unrelated hook and setting. Remove only our marked hook entries.
    public static func updating(_ input: Data?, executable: String?, home: String) throws -> Data {
        var settings: [String: Any] = [:]
        if let input {
            guard let object = try JSONSerialization.jsonObject(with: input) as? [String: Any] else { throw IntegrationError.invalidSettings }
            settings = object
        }
        if let existing = settings["hooks"], !(existing is [String: Any]) { throw IntegrationError.invalidSettings }
        var hooks = settings["hooks"] as? [String: Any] ?? [:]
        for event in ["Stop", "UserPromptSubmit"] {
            if let existing = hooks[event], !(existing is [[String: Any]]) { throw IntegrationError.invalidSettings }
            var groups = hooks[event] as? [[String: Any]] ?? []
            groups = groups.compactMap { group in
                guard let entries = group["hooks"] as? [[String: Any]] else { return group }
                let remaining = entries.filter { !(($0["command"] as? String ?? "").contains(marker)) }
                if remaining.isEmpty && !entries.isEmpty { return nil }
                var kept = group; kept["hooks"] = remaining; return kept
            }
            if let executable {
                let command = shellQuote(executable) + " " + marker + " claude"
                groups.append(["hooks": [["type": "command", "command": command, "timeout": 3]]])
            }
            if groups.isEmpty { hooks.removeValue(forKey: event) } else { hooks[event] = groups }
        }
        settings["hooks"] = hooks
        return try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    }
    public static func write(settings: URL, executable: String?) throws -> URL? {
        let fm = FileManager.default
        let exists = fm.fileExists(atPath: settings.path)
        let input = exists ? try Data(contentsOf: settings) : nil
        let output = try updating(input, executable: executable, home: fm.homeDirectoryForCurrentUser.path)
        try fm.createDirectory(at: settings.deletingLastPathComponent(), withIntermediateDirectories: true)
        var backup: URL?
        if let input {
            backup = settings.deletingLastPathComponent().appendingPathComponent("settings.doclin-backup-\(UUID().uuidString).json")
            try input.write(to: backup!, options: .atomic)
            try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: backup!.path)
        }
        try output.write(to: settings, options: .atomic)
        try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: settings.path)
        return backup
    }
    public enum IntegrationError: Error { case invalidSettings }
}
