import AppKit
import AVFoundation
import SwiftUI
import ServiceManagement
import DoclinCore

struct Announcement: Identifiable {
    let id: UUID
    var event: AgentEvent
    var text: String
    var state: String
    var mode: String
}

@MainActor final class AppModel: NSObject, ObservableObject, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {
    @Published var preferences = Preferences.load()
    @Published var history: [Announcement] = []
    @Published var watchedCount = 0
    @Published var pendingCount = 0
    @Published var speaking = false
    @Published var status = "Ready for your next finish"
    @Published var notice = ""
    @Published var hasKey = false
    @Published var claudeInstalled = false
    @Published var loginEnabled = false
    @Published var tab = "Dictation"
    let dictation = DictationController()
    private var dictationBusy = false
    private var policy = QueuePolicy()
    private var watcher: EventWatcher?
    private var synthesizer = AVSpeechSynthesizer()
    private var player: AVAudioPlayer?
    private var worker: Task<Void, Never>?
    private var current: AgentEvent?
    private var currentID: UUID?
    private var generation = UUID()
    private var lastPrompts: [String: String] = [:]
    private var cloud = CloudService()
    private let localVoice = LocalVoice()
    private let routeMonitor = AudioRouteMonitor()
    private var speechFile: AVAudioFile?
    private var speechURL: URL?
    @Published var outputName = AudioRoute.current()?.name ?? "No output available"
    var hasLocalVoice: Bool { LocalVoice.available }
    private var expiryTimer: Timer?
    private var key: String?
    private var apiCalls = 0
    private var apiDay = Calendar.current.startOfDay(for: Date())
    private let settingsURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/settings.json")
    var voices: [AVSpeechSynthesisVoice] { AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("en") }.sorted { $0.name < $1.name } }
    override init() {
        super.init()
        key = Keychain.read(); hasKey = key != nil
        dictation.keyProvider = { [weak self] in self?.key }
        dictation.onBusyChange = { [weak self] busy in
            guard let self else { return }
            self.dictationBusy = busy
            if busy { self.stopCurrent(reason: "Dictating"); self.status = "Dictation in progress" }
            else { self.status = self.preferences.muted ? "Announcements paused" : "Ready for your next finish"; self.startNext() }
        }
        claudeInstalled = ClaudeIntegration.installed(at: settingsURL)
        loginEnabled = SMAppService.mainApp.status == .enabled
        // System speech is rendered to buffers, then uses the same routed player.
        synthesizer.delegate = nil
        routeMonitor.changed = { [weak self] in
            guard let self else { return }
            self.outputName = AudioRoute.current()?.name ?? "No output available"
            if self.current != nil || self.pendingCount > 0 {
                self.policy.clear(); self.pendingCount = 0
                for i in self.history.indices where self.history[i].state == "Queued" { self.history[i].state = "Audio output changed" }
                self.stopCurrent(reason: "Audio output changed")
            }
        }
        policy.lifetime = preferences.expiry
        DoclinPaths.cleanInbox(all: true)
        DoclinPaths.beat()
        try? DoclinPaths.prepare()
        restartWatcher()
        expiryTimer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in Task { @MainActor in self?.expireCurrent() } }
        if let expiryTimer { RunLoop.main.add(expiryTimer, forMode: .common) }
    }
    func restartWatcher() {
        watcher?.stop()
        let root = URL(fileURLWithPath: (preferences.codexHome as NSString).expandingTildeInPath)
        watcher = EventWatcher(root: root, callback: { [weak self] event in Task { @MainActor in self?.receive(event) } }, status: { [weak self] count in Task { @MainActor in self?.watchedCount = count } })
        watcher?.start()
    }
    func save() {
        do { try preferences.save() } catch { notice = "Could not save preferences: \(error.localizedDescription)" }
        policy.lifetime = preferences.expiry
        // Settings changes take effect immediately, including revoking cloud access.
        stopCurrent(reason: "Settings changed")
        policy.clear(); pendingCount = 0
        for i in history.indices where history[i].state == "Queued" { history[i].state = "Settings changed" }
    }
    func toggleMute() {
        preferences.muted.toggle(); save()
        status = preferences.muted ? "Announcements paused" : "Ready for your next finish"
    }
    func stopAll() {
        policy.clear(); pendingCount = 0
        stopCurrent(reason: "Stopped")
        history.indices.filter { history[$0].state == "Queued" }.forEach { history[$0].state = "Skipped" }
        status = "Playback stopped"
    }
    func receive(_ original: AgentEvent) {
        var event = original
        if event.kind == "start" {
            if !event.prompt.isEmpty { lastPrompts[event.key] = event.prompt }
            if lastPrompts.count > 200 { lastPrompts = [event.key: event.prompt] }
            _ = policy.receive(event)
            if current?.key == event.key, event.timestamp >= (current?.timestamp ?? .distantPast) { stopCurrent(reason: "New message") }
            for i in history.indices where history[i].event.key == event.key && history[i].state == "Queued" { history[i].state = "Superseded" }
            pendingCount = policy.pending.count; startNext(); return
        }
        guard preferences.allows(event), !preferences.muted else { return }
        if event.prompt.isEmpty { event.prompt = lastPrompts[event.key] ?? "" }
        guard policy.receive(event) else { return }
        if current?.key == event.key { stopCurrent(reason: "Newer response") }
        for i in history.indices where history[i].event.key == event.key && history[i].state == "Queued" { history[i].state = "Superseded" }
        history.insert(Announcement(id: UUID(), event: event, text: SpeechText.excerpt(event, words: preferences.wordLimit), state: "Queued", mode: "Local excerpt"), at: 0)
        history = Array(history.prefix(30)); pendingCount = policy.pending.count
        startNext()
    }
    func preview() {
        guard !preferences.muted else { notice = "Resume announcements to preview the voice."; return }
        receive(AgentEvent(source: "Preview", session: "preview", text: "The missing stage labels are fixed. Tests pass; changes are ready for review.", project: "Buyer pipeline", prompt: "Fix missing buyer stage labels"))
    }
    private func updateCurrent(_ state: String, text: String? = nil, mode: String? = nil) {
        guard let i = history.firstIndex(where: { $0.id == currentID }) else { return }
        history[i].state = state
        if let text { history[i].text = text }
        if let mode { history[i].mode = mode }
    }
    private func startNext() {
        guard current == nil, !preferences.muted, !dictationBusy, let event = policy.next() else { pendingCount = policy.pending.count; return }
        pendingCount = policy.pending.count
        current = event; currentID = history.first(where: { $0.event.id == event.id })?.id
        let ticket = UUID(); generation = ticket
        status = "Preparing a short update"; updateCurrent("Preparing")
        worker = Task { [weak self] in
            guard let self else { return }
            // Give a quick follow-up time to cancel before sending text or playing audio.
            do { try await Task.sleep(nanoseconds: 700_000_000) } catch { return }
            guard self.valid(ticket) else { return }
            var text = SpeechText.excerpt(event, words: preferences.wordLimit)
            var mode = "Local excerpt"
            if preferences.useAI, let key, reserveCloudCall() {
                do { text = try await cloud.summarize(event, key: key, words: preferences.wordLimit); mode = "AI summary" }
                catch { if valid(ticket) { notice = error.localizedDescription } }
            }
            guard valid(ticket) else { return }
            updateCurrent("Preparing", text: text, mode: mode)
            if preferences.aiVoice, let key, reserveCloudCall() {
                do {
                    let audio = try await cloud.speech(text, key: key, voice: preferences.voice, rate: preferences.rate)
                    guard valid(ticket) else { return }
                    try playAudio(audio, mode: mode)
                    return
                } catch { if valid(ticket) { notice = error.localizedDescription } }
            }
            guard valid(ticket) else { return }
            if let speaker = LocalVoiceChoice.speaker(for: preferences.systemVoice) {
                guard LocalVoice.available else {
                    notice = "The local voice is unavailable. Update kept in Agent updates."
                    stopCurrent(reason: "Voice unavailable"); startNext(); return
                }
                do {
                    let audio = try await localVoice.synthesize(text, rate: preferences.rate, speaker: speaker)
                    guard valid(ticket) else { return }
                    try playAudio(audio, mode: mode + " · " + (LocalVoiceChoice.choices.first { $0.speaker == speaker }?.name ?? "Kokoro"))
                    return
                } catch {
                    if valid(ticket) {
                        notice = "The local voice could not play. Update kept in Agent updates."
                        stopCurrent(reason: "Voice unavailable"); startNext()
                    }
                    return
                }
            }
            guard valid(ticket) else { return }
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = preferences.systemVoice.isEmpty ? AVSpeechSynthesisVoice(language: "en-US") : AVSpeechSynthesisVoice(identifier: preferences.systemVoice)
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * Float(preferences.rate)
            utterance.volume = 1.0
            renderMacVoice(utterance, ticket: ticket, mode: mode)
        }
    }
    private func playAudio(_ audio: Data, mode: String) throws {
        guard let route = AudioRoute.current() else { throw CloudService.CloudError.invalidResponse }
        let p = try AVAudioPlayer(data: audio)
        p.volume = Float(preferences.volume); p.delegate = self
        guard route.configure(p), AudioRoute.current()?.uid == route.uid else { throw CloudService.CloudError.invalidResponse }
        player = p
        guard p.play() else { player = nil; throw CloudService.CloudError.invalidResponse }
        outputName = route.name
        speaking = true; status = "Speaking through " + route.name
        updateCurrent("Speaking", mode: mode + " · " + route.name)
    }
    private func renderMacVoice(_ utterance: AVSpeechUtterance, ticket: UUID, mode: String) {
        let folder = DoclinPaths.support.appendingPathComponent("voice-audio")
        let url = folder.appendingPathComponent(UUID().uuidString + ".caf")
        speechURL = url; speechFile = nil
        synthesizer.write(utterance) { [weak self] buffer in
            // Preserve callback ordering and retain each audio buffer until it is written.
            DispatchQueue.main.async {
                guard let self, self.valid(ticket) else { return }
                guard let pcm = buffer as? AVAudioPCMBuffer else { return }
                do {
                    if pcm.frameLength > 0 {
                        if self.speechFile == nil { self.speechFile = try AVAudioFile(forWriting: url, settings: pcm.format.settings) }
                        try self.speechFile?.write(from: pcm)
                    } else {
                        self.speechFile = nil
                        let audio = try Data(contentsOf: url)
                        self.cleanSpeechFile()
                        try self.playAudio(audio, mode: mode + " · Mac voice")
                    }
                } catch {
                    self.cleanSpeechFile()
                    self.notice = "Could not play through the selected audio output. Update kept in Agent updates."
                    self.stopCurrent(reason: "Audio unavailable"); self.startNext()
                }
            }
        }
    }
    private func cleanSpeechFile() {
        speechFile = nil
        if let speechURL { try? FileManager.default.removeItem(at: speechURL) }
        speechURL = nil
    }
    private func reserveCloudCall() -> Bool {
        let today = Calendar.current.startOfDay(for: Date())
        if today != apiDay { apiDay = today; apiCalls = 0 }
        if apiCalls >= 500 { notice = "The session's daily limit of 500 API requests was reached. Using local speech."; return false }
        apiCalls += 1; return true
    }
    private func valid(_ ticket: UUID) -> Bool { generation == ticket && !Task.isCancelled && !preferences.muted && current.map { Date().timeIntervalSince($0.timestamp) <= preferences.expiry } == true }
    private func expireCurrent() {
        DoclinPaths.beat()
        if let current, !speaking, Date().timeIntervalSince(current.timestamp) > preferences.expiry { stopCurrent(reason: "Expired"); startNext() }
        for i in history.indices where history[i].state == "Queued" && Date().timeIntervalSince(history[i].event.timestamp) > preferences.expiry { history[i].state = "Expired" }
    }
    private func stopCurrent(reason: String) {
        generation = UUID(); worker?.cancel(); worker = nil
        player?.delegate = nil; player?.stop(); player = nil
        // A new synthesizer prevents a delayed cancel callback from finishing a newer job.
        synthesizer.delegate = nil; synthesizer.stopSpeaking(at: .immediate)
        synthesizer = AVSpeechSynthesizer(); synthesizer.delegate = nil
        cleanSpeechFile()
        updateCurrent(reason); current = nil; currentID = nil; speaking = false
        status = preferences.muted ? "Announcements paused" : "Ready for your next finish"
    }
    private func finished() {
        updateCurrent("Spoken"); current = nil; currentID = nil; speaking = false; player = nil
        status = "Ready for your next finish"; startNext()
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) { Task { @MainActor in if synthesizer === self.synthesizer { self.finished() } } }
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) { Task { @MainActor in if player === self.player { if flag { self.finished() } else { self.stopCurrent(reason: "Playback failed"); self.startNext() } } } }
    func saveKey(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { notice = "Enter an OpenAI API key first."; return }
        do { try Keychain.save(trimmed); key = trimmed; hasKey = true; notice = "API key saved in this Mac’s Keychain." }
        catch { notice = "Could not save the key in Keychain." }
    }
    func removeKey() { dictation.cancel(showMessage: false); Keychain.delete(); key = nil; hasKey = false; preferences.useAI = false; preferences.aiVoice = false; save(); notice = "API key removed. Speech stays on this Mac." }
    func setLogin(_ enabled: Bool) {
        do { if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }; loginEnabled = SMAppService.mainApp.status == .enabled; if !loginEnabled && enabled { notice = "Approve Doclin in System Settings → General → Login Items." } }
        catch { notice = "Login setup needs Doclin installed in Applications. \(error.localizedDescription)" }
    }
    func connectClaude(_ connect: Bool) {
        do {
            var helper: String?
            if connect {
                guard let executable = Bundle.main.executableURL else { return }
                let bin = DoclinPaths.support.appendingPathComponent("bin")
                try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
                let dest = bin.appendingPathComponent("doclin-hook")
                let data = try Data(contentsOf: executable)
                try data.write(to: dest, options: .atomic)
                try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dest.path)
                helper = dest.path
            }
            _ = try ClaudeIntegration.write(settings: settingsURL, executable: helper)
            claudeInstalled = ClaudeIntegration.installed(at: settingsURL)
            notice = connect ? "Claude connected. Restart existing Claude Code sessions to load the hooks. Existing hooks were preserved." : "Doclin’s Claude hooks removed. Other hooks were preserved."
        } catch { notice = "Claude setup was not changed: \(error.localizedDescription)" }
    }
    func shutdown() { routeMonitor.stop();
        expiryTimer?.invalidate(); watcher?.stop(); stopAll()
        try? FileManager.default.removeItem(at: DoclinPaths.heartbeat)
        DoclinPaths.cleanInbox(all: true)
        dictation.shutdown()
    }
    func clearHistory() { stopAll(); history.removeAll() }
}
