import Foundation
import DoclinCore

final class CoreTests {
    func testAudioMeterShowsQuietSpeechAndRejectsSilence() {
        XCTAssertEqual(AudioMeter.level(rms: 0), 0)
        XCTAssertEqual(AudioMeter.level(decibels: -80), 0)
        XCTAssertTrue(AudioMeter.level(rms: 0.005) > 0.25)
        XCTAssertTrue(AudioMeter.level(rms: 0.05) > AudioMeter.level(rms: 0.005))
        XCTAssertEqual(AudioMeter.level(rms: 1), 1)
        XCTAssertEqual(AudioMeter.level(rms: .nan), 0)
        XCTAssertEqual(AudioMeter.level(decibels: -.infinity), 0)
    }
    func testDictationHistoryRetainsSessionsWithoutDuplicatesOrEmptyText() {
        var history = DictationHistory()
        let id = UUID(), date = Date()
        history.record(id: id, text: "First", original: "first", destination: "Notes", timestamp: date)
        history.record(id: id, text: "Duplicate", original: "duplicate", destination: "Notes", timestamp: date)
        history.record(id: UUID(), text: "  ", original: "", destination: "Notes", timestamp: date)
        XCTAssertEqual(history.entries.count, 1)
        for i in 0..<35 { history.record(id: UUID(), text: "Text \(i)", original: "Text \(i)", destination: "Notes", timestamp: date) }
        XCTAssertEqual(history.entries.count, 30)
        XCTAssertEqual(history.entries.first?.text, "Text 34")
        XCTAssertEqual(history.entries.last?.text, "Text 5")
    }
    func testDictationHistoryEditsKeepOriginalAndClearingIsSessionOnly() {
        var history = DictationHistory()
        let id = UUID()
        history.record(id: id, text: "Polished", original: "Original 123", destination: "Notes", timestamp: Date())
        history.setState(id, state: "Cleaning up")
        history.setState(id, state: "Text retained")
        XCTAssertEqual(history.entries.first?.original, "Original 123")
        history.applyResult(id, text: "Cleaned 123")
        XCTAssertEqual(history.entries.count, 1)
        XCTAssertEqual(history.entries.first?.original, "Original 123")
        history.setState(id, state: "Inserted")
        history.edit(id, text: "Edited 123")
        XCTAssertEqual(history.entries.first?.original, "Original 123")
        XCTAssertEqual(history.entries.first?.state, "Edited")
        history.edit(id, text: "Original 123")
        XCTAssertEqual(history.entries.first?.state, "Original text")
        history.clear()
        XCTAssertTrue(history.entries.isEmpty)
        XCTAssertTrue(DictationHistory().entries.isEmpty)
    }

    func event(_ turn: String, session: String = "a", kind: String = "complete", age: Double = 0) -> AgentEvent {
        AgentEvent(source: "Codex", session: session, turn: turn, kind: kind, text: "Tests failed. Deployment is blocked.", timestamp: Date().addingTimeInterval(-age))
    }
    func testDuplicateCompletionOnlySpeaksOnce() {
        var q = QueuePolicy(); let e = event("1")
        XCTAssertTrue(q.receive(e)); XCTAssertFalse(q.receive(e)); XCTAssertEqual(q.pending.count, 1)
    }
    func testNewCompletionReplacesSameTaskOnly() {
        var q = QueuePolicy(); _ = q.receive(event("1")); _ = q.receive(event("2", session: "b")); _ = q.receive(event("3"))
        XCTAssertEqual(q.pending.map(\.turn), ["2", "3"])
    }
    func testNewPromptCancelsPending() {
        var q = QueuePolicy(); _ = q.receive(event("1", age: 2)); _ = q.receive(event("2", kind: "start"))
        XCTAssertTrue(q.pending.isEmpty)
    }
    func testDelayedOldCompletionCannotReappearAfterNewPrompt() {
        var q = QueuePolicy(); _ = q.receive(event("new", kind: "start"))
        XCTAssertFalse(q.receive(event("old", age: 2)))
    }
    func testOldAnnouncementsExpireBeforeAdmissionAndPlayback() {
        var q = QueuePolicy(); XCTAssertFalse(q.receive(event("old", age: 45)))
        let e = event("fresh"); XCTAssertTrue(q.receive(e)); XCTAssertNil(q.next(now: Date().addingTimeInterval(40)))
    }
    func testQueueIsBounded() {
        var q = QueuePolicy(); for i in 0..<30 { _ = q.receive(event("\(i)", session: "\(i)")) }; XCTAssertEqual(q.pending.count, 10)
    }
    func testFormattingDoesNotReadCodeURLsOrMarkdown() {
        let input = "## Result\n**Tests failed**. [Review](https://example.com)\n```sh\nrm -rf dangerous\n```"
        let text = SpeechText.clean(input)
        XCTAssertEqual(text, "Result Tests failed. Review")
    }
    func testExcerptPreservesNegativeOutcomeAndWordCap() {
        let e = event("1")
        let s = SpeechText.excerpt(e, words: 20)
        XCTAssertTrue(s.contains("Tests failed")); XCTAssertFalse(s.contains("success"))
        XCTAssertLessThanOrEqual(SpeechText.limited(String(repeating: "word ", count: 200)).split(separator: " ").count, 20)
    }
    func testEmptyCompletionIsNotClaimedSuccess() {
        XCTAssertEqual(SpeechText.excerpt(AgentEvent(source: "Claude", session: "a"), words: 20), "Response ready.")
    }
    func parse(_ object: [String: Any], using parser: CodexParser) -> AgentEvent? { parser.parse(try! JSONSerialization.data(withJSONObject: object)) }
    func testCodexDesktopShapeAndSubagentExclusion() {
        let p = CodexParser()
        XCTAssertNil(parse(["type": "session_meta", "payload": ["id": "a", "cwd": "/tmp/project", "originator": "Codex Desktop", "thread_source": "user"]], using: p))
        let e = parse(["timestamp": "2026-09-07T14:00:00.000Z", "type": "event_msg", "payload": ["type": "task_complete", "turn_id": "t", "last_agent_message": "Fixed locally; not deployed."]], using: p)
        XCTAssertEqual(e?.text, "Fixed locally; not deployed."); XCTAssertEqual(e?.session, "a"); XCTAssertEqual(e?.project, "project")
        _ = parse(["type": "session_meta", "payload": ["id": "b", "source": ["subagent": ["parent_thread_id": "a"]]]], using: p)
        XCTAssertNil(parse(["timestamp": "2026-09-07T14:00:00Z", "type": "event_msg", "payload": ["type": "task_complete", "last_agent_message": "Do not speak"]], using: p))
    }
    func testCodexUnknownTimestampAndToolOutputsAreIgnored() {
        let p = CodexParser(); p.session = "a"
        XCTAssertNil(parse(["type": "event_msg", "payload": ["type": "task_complete"]], using: p))
        XCTAssertNil(parse(["type": "response_item", "payload": ["type": "function_call_output", "output": "hello"]], using: p))
    }
    func testClaudeHookNormalizesStopAndStartButNotSubagents() throws {
        func hook(_ name: String) -> AgentEvent? { HookParser.parse(try! JSONSerialization.data(withJSONObject: ["session_id": "a", "hook_event_name": name, "last_assistant_message": "Done", "cwd": "/tmp/p"]), source: "claude") }
        XCTAssertEqual(hook("Stop")?.kind, "complete"); XCTAssertEqual(hook("UserPromptSubmit")?.kind, "start"); XCTAssertNil(hook("SubagentStop"))
        XCTAssertNil(HookParser.parse(Data("not json".utf8), source: "claude"))
    }
    func testIntegrationPreservesOtherHooksAndIsIdempotent() throws {
        let original = Data(#"{"theme":"dark","hooks":{"Stop":[{"hooks":[{"type":"command","command":"heard stop"}]}],"SessionStart":[{"hooks":[{"command":"existing"}]}]}}"#.utf8)
        let first = try ClaudeIntegration.updating(original, executable: "/tmp/a b/doclin", home: "/tmp")
        let second = try ClaudeIntegration.updating(first, executable: "/tmp/a b/doclin", home: "/tmp")
        XCTAssertEqual(first, second)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: second) as? [String: Any])
        XCTAssertEqual(json["theme"] as? String, "dark")
        XCTAssertTrue(String(data: second, encoding: .utf8)!.contains("heard stop"))
        let removed = try ClaudeIntegration.updating(second, executable: nil, home: "/tmp")
        XCTAssertFalse(String(data: removed, encoding: .utf8)!.contains("--doclin-hook"))
        XCTAssertTrue(String(data: removed, encoding: .utf8)!.contains("heard stop"))
    }
    func testInvalidSettingsFailWithoutOverwriting() {
        XCTAssertThrowsError(try ClaudeIntegration.updating(Data("invalid".utf8), executable: "/tmp/a", home: "/tmp"))
        XCTAssertThrowsError(try ClaudeIntegration.updating(Data(#"{"hooks":"wrong"}"#.utf8), executable: "/tmp/a", home: "/tmp"))
    }
    func testShellQuotingCannotExecutePathContent() {
        XCTAssertEqual(ClaudeIntegration.shellQuote("/tmp/a'b $(touch bad)"), "'/tmp/a'\\''b $(touch bad)'")
    }
    func testTailBuffersPartialLinesAndDoesNotReplayBaseline() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let meta = "{\"type\":\"session_meta\",\"payload\":{\"id\":\"a\"}}\n"
        try Data(meta.utf8).write(to: url)
        let tail = JSONLTail(url: url, fromEnd: true)
        XCTAssertTrue(tail.poll().isEmpty)
        let h = try FileHandle(forWritingTo: url); defer { try? h.close() }; try h.seekToEnd()
        let line = "{\"timestamp\":\"2026-09-07T14:00:00Z\",\"type\":\"event_msg\",\"payload\":{\"type\":\"task_complete\",\"turn_id\":\"x\",\"last_agent_message\":\"Ready\"}}"
        try h.write(contentsOf: Data(line.utf8)); XCTAssertTrue(tail.poll().isEmpty)
        try h.write(contentsOf: Data("\n".utf8)); XCTAssertEqual(tail.poll().first?.text, "Ready"); XCTAssertTrue(tail.poll().isEmpty)
    }
    func testCloudResponseParsesMessagesAfterReasoningAndRejectsPartial() throws {
        let data = Data(#"{"status":"completed","output":[{"type":"reasoning"},{"type":"message","content":[{"type":"output_text","text":"Tests failed; review the changes."}]}]}"#.utf8)
        XCTAssertEqual(try CloudService.parseSummary(data, words: 20), "Tests failed; review the changes.")
        XCTAssertThrowsError(try CloudService.parseSummary(Data(#"{"status":"incomplete","output":[]}"#.utf8), words: 20))
    }
    func testProjectExclusionAndSourceToggles() {
        var p = Preferences(); p.codexEnabled = false; XCTAssertFalse(p.allows(event("a")))
        p.codexEnabled = true; p.excludedProjects = "private, Finance"
        XCTAssertFalse(p.allows(AgentEvent(source: "Claude", session: "a", project: "finance")))
    }
    func testProducerDoesNotCollectWhenAppIsClosedOrMuted() throws {
        try? FileManager.default.removeItem(at: DoclinPaths.heartbeat)
        try DoclinPaths.spool(event("closed"))
        let count = { (try? FileManager.default.contentsOfDirectory(at: DoclinPaths.inbox, includingPropertiesForKeys: nil).filter { $0.pathExtension == "json" }.count) ?? 0 }
        XCTAssertEqual(count(), 0)
        DoclinPaths.beat()
        XCTAssertTrue(DoclinPaths.isRunning())
        try DoclinPaths.spool(event("live")); XCTAssertEqual(count(), 1)
        DoclinPaths.cleanInbox(all: true)
        var p = Preferences(); p.muted = true; try p.save()
        try DoclinPaths.spool(event("muted")); XCTAssertEqual(count(), 0)
        p.muted = false; p.codexEnabled = false; try p.save()
        try DoclinPaths.spool(event("disabled")); XCTAssertEqual(count(), 0)
        p.codexEnabled = true; p.expiry = 60; try p.save()
        XCTAssertEqual(Preferences.load().expiry, 60)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-10)], ofItemAtPath: DoclinPaths.heartbeat.path)
        XCTAssertFalse(DoclinPaths.isRunning())
        try DoclinPaths.spool(event("stale")); XCTAssertEqual(count(), 0)
        try Preferences().save()
    }
    func testWatcherDeliversFreshLifecycleEventsWithoutReplayingOldFiles() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let sessions = root.appendingPathComponent("sessions")
        let inbox = root.appendingPathComponent("inbox")
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = sessions.appendingPathComponent("fixture.jsonl")
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        func line(_ payload: [String: Any], type: String = "event_msg", date: Date = Date()) throws -> Data {
            var data = try JSONSerialization.data(withJSONObject: ["timestamp": formatter.string(from: date), "type": type, "payload": payload]); data.append(10); return data
        }
        var initial = try line(["id": "fixture", "cwd": "/tmp/Doclin checks"], type: "session_meta")
        initial.append(try line(["type": "task_complete", "turn_id": "old", "last_agent_message": "Should stay quiet"], date: Date().addingTimeInterval(-60)))
        try initial.write(to: url)
        let ready = DispatchSemaphore(value: 0); let delivered = DispatchSemaphore(value: 0)
        let lock = NSLock(); var received: [AgentEvent] = []
        let watcher = EventWatcher(root: root, inbox: inbox, callback: { event in
            lock.lock(); received.append(event); lock.unlock(); delivered.signal()
        }, status: { _ in ready.signal() })
        watcher.start(); defer { watcher.stop() }
        XCTAssertEqual(ready.wait(timeout: .now() + 3), .success)
        Thread.sleep(forTimeInterval: 0.05)
        let h = try FileHandle(forWritingTo: url); try h.seekToEnd()
        try h.write(contentsOf: line(["type": "task_started", "turn_id": "fresh"]))
        try h.write(contentsOf: line(["type": "task_complete", "turn_id": "fresh", "last_agent_message": "A real file event reached the app."]))
        try h.close()
        XCTAssertEqual(delivered.wait(timeout: .now() + 3), .success)
        XCTAssertEqual(delivered.wait(timeout: .now() + 3), .success)
        lock.lock(); let result = received; lock.unlock()
        XCTAssertEqual(result.map(\.kind), ["start", "complete"])
        XCTAssertEqual(result.last?.turn, "fresh")
    }

}
