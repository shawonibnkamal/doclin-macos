import Foundation

/// Bounded incremental reads. Partial JSON lines remain buffered until a newline arrives.
public final class JSONLTail {
    public let url: URL
    public var offset: UInt64 = 0
    private var buffer = Data()
    private var discardingOversizedLine = false
    public let parser = CodexParser()
    public init(url: URL, fromEnd: Bool) {
        self.url = url
        if let handle = try? FileHandle(forReadingFrom: url) {
            defer { try? handle.close() }
            // Metadata is always the first line; don't load a complete transcript.
            let data = (try? handle.read(upToCount: 1_048_576)) ?? Data()
            if let newline = data.firstIndex(of: 10) { _ = parser.parse(Data(data[..<newline])) }
            if fromEnd { offset = (try? handle.seekToEnd()) ?? 0 }
        }
    }
    public func poll() -> [AgentEvent] {
        guard let h = try? FileHandle(forReadingFrom: url) else { return [] }
        defer { try? h.close() }
        let end = (try? h.seekToEnd()) ?? 0
        if end < offset { offset = 0; buffer.removeAll(); discardingOversizedLine = false }
        guard end > offset else { return [] }
        try? h.seek(toOffset: offset)
        guard let data = try? h.read(upToCount: 1_048_576), !data.isEmpty else { return [] }
        offset += UInt64(data.count)
        buffer.append(data)
        var events: [AgentEvent] = []
        while let newline = buffer.firstIndex(of: 10) {
            let line = Data(buffer[..<newline])
            buffer.removeSubrange(...newline)
            if !discardingOversizedLine, let e = parser.parse(line) { events.append(e) }
            discardingOversizedLine = false
        }
        if buffer.count > 2_097_152 { buffer.removeAll(); discardingOversizedLine = true }
        return events
    }
}

public final class EventWatcher {
    private let queue = DispatchQueue(label: "dev.doclin.watcher", qos: .utility)
    private var timer: DispatchSourceTimer?
    private var tails: [String: JSONLTail] = [:]
    private var tick = 0
    private var startup = Date()
    private let root: URL
    private let inbox: URL
    private let callback: (AgentEvent) -> Void
    private let status: (Int) -> Void
    public init(root: URL, inbox: URL = DoclinPaths.inbox, callback: @escaping (AgentEvent) -> Void, status: @escaping (Int) -> Void) {
        self.root = root; self.inbox = inbox; self.callback = callback; self.status = status
    }
    public func start() {
        queue.async { [self] in
            startup = Date()
            discover(baseline: true)
            let timer = DispatchSource.makeTimerSource(queue: queue)
            timer.schedule(deadline: .now(), repeating: 0.5)
            timer.setEventHandler { [weak self] in self?.poll() }
            self.timer = timer; timer.resume()
        }
    }
    public func stop() { queue.async { [self] in timer?.cancel(); timer = nil; tails.removeAll() } }
    private func discover(baseline: Bool) {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: root.appendingPathComponent("sessions"), includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey], options: [.skipsHiddenFiles]) else { status(0); return }
        for case let url as URL in enumerator {
            guard url.pathExtension == "jsonl", tails[url.path] == nil,
                  let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]), values.isRegularFile == true,
                  let modified = values.contentModificationDate, Date().timeIntervalSince(modified) < 86400 * 2 else { continue }
            // For newly discovered sessions, read from start and reject timestamps predating startup.
            tails[url.path] = JSONLTail(url: url, fromEnd: baseline)
        }
        // Bound watcher lifetime state without forgetting a file that is still being used.
        tails = tails.filter { path, _ in
            guard let attrs = try? fm.attributesOfItem(atPath: path), let date = attrs[.modificationDate] as? Date else { return false }
            return Date().timeIntervalSince(date) < 86400 * 2
        }
        status(tails.values.filter { !$0.parser.isSubagent }.count)
    }
    private func poll() {
        tick += 1
        if tick % 10 == 0 { discover(baseline: false) }
        var incoming: [AgentEvent] = []
        for tail in tails.values { incoming += tail.poll().filter { $0.timestamp >= startup } }
        if let files = try? FileManager.default.contentsOfDirectory(at: inbox, includingPropertiesForKeys: [.fileSizeKey]) {
            for file in files where file.pathExtension == "json" {
                let size = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? Int.max
                if size < 65536, let data = try? Data(contentsOf: file), let e = try? JSONDecoder().decode(AgentEvent.self, from: data), Date().timeIntervalSince(e.timestamp) < 30, e.timestamp >= startup { incoming.append(e) }
                try? FileManager.default.removeItem(at: file)
            }
        }
        for event in incoming.sorted(by: { $0.timestamp < $1.timestamp }) { callback(event) }
    }
}
