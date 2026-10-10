import AppKit
import AVFoundation
import Speech
import SwiftUI
import DoclinCore

@MainActor final class DictationController: NSObject, ObservableObject {
    @Published var settings = DictationPreferences.load()
    @Published var phase = "Ready" { didSet { hudGeneration = UUID(); updateIndicator() } }
    @Published var history = DictationHistory()
    @Published var transcript = ""
    @Published var originalTranscript = ""
    @Published var message = "Hold the shortcut in a text field to dictate."
    @Published var partial = ""
    @Published var seconds = 0
    @Published var level: Float = 0
    @Published var shortcutReady = false
    @Published var microphoneGranted = false
    @Published var speechGranted = false
    @Published var accessibilityGranted = false
    @Published var targetName = "Doclin"
    var keyProvider: () -> String? = { nil }
    var openSettings: () -> Void = {}
    @Published private var indicatorArmed = false
    private var hudPresented = false
    @Published var startSoundEnabled = UserDefaults.standard.object(forKey: "dictationStartSound") as? Bool ?? true
    private let startCue = DictationStartCue()
    @Published var indicatorPreview = false
    @Published private var previewState: DictationIndicatorState = .ready
    private var previewTask: Task<Void, Never>?
    private var permissionTimer: Timer?
    private var hudGeneration = UUID()
    var indicatorState: DictationIndicatorState {
        if indicatorPreview { return previewState }
        if indicatorArmed || recording { return .listening }
        if busy { return .processing }
        if phase == "Needs attention" || phase == "Language unavailable" || phase == "API key needed" { return .error }
        if phase == "Inserted" { return .success }
        if phase == "Text ready" || phase == "Paste requested" { return .retained }
        if phase == "Canceled" { return .canceled }
        if !settings.enabled { return .off }
        if !microphoneGranted || (settings.provider == "local" && !modernReady && !speechGranted) || !shortcutReady { return .setup }
        return .ready
    }
    var indicatorTitle: String {
        switch indicatorState {
        case .off: return "Dictation is off"
        case .setup: return "Finish dictation setup"
        case .ready: return "Hold \(shortcutLabel) to dictate"
        case .listening: return indicatorArmed || microphoneStarting ? "Starting dictation" : "Listening"
        case .processing: return phase == "Cleaning up" ? "Polishing your words" : "Transcribing"
        case .success: return "Inserted into \(targetName)"
        case .retained: return "Your text is ready"
        case .error: return "Dictation needs attention"
        case .canceled: return "Dictation canceled"
        }
    }
    var indicatorSubtitle: String {
        if indicatorPreview { return "UI preview · no recording" }
        switch indicatorState {
        case .setup:
            if !accessibilityGranted && settings.shortcut == "right-command" { return "Right Command needs Accessibility permission" }
            if !microphoneGranted { return "Microphone permission needed" }
            if !modernReady && !speechGranted && settings.provider == "local" { return "Speech Recognition permission needed" }
            return "Choose an available shortcut in settings"
        case .listening: return indicatorArmed || microphoneStarting ? "Starting microphone…" : "Release \(shortcutLabel) or click stop to finish"
        case .processing: return "Recording stopped"
        case .success: return "Done · nothing was sent"
        case .retained: return phase == "Paste requested" ? "Paste requested · check the destination" : "Copy it here or open Doclin"
        case .error: return "Open setup for details"
        case .canceled: return insertionStarted ? "Check your field; insertion had already started" : "No text was inserted"
        case .off: return "Enable dictation in Doclin"
        case .ready: return "Or click the microphone · Doclin"
        }
    }
    var indicatorStarting: Bool { !indicatorPreview && (indicatorArmed || microphoneStarting) }
    var indicatorHeight: CGFloat { 38 }
    var indicatorWidth: CGFloat { 184 }
    var indicatorLevel: Float { indicatorPreview ? 0.6 : level }
    var onBusyChange: (Bool) -> Void = { _ in }
    private let hotkey = DictationHotkey()
    private let insertion = TextInsertion()
    private var target: TextInsertion.Target?
    private var lifecycle = DictationLifecycle()
    private let capture = DictationCapture()
    private var captureStream: (any DictationAudioSink)?
    private var modernSession: AnyObject?
    private var preparedModernSession: AnyObject?
    private var preparationTask: Task<Void, Never>?
    private var assetTask: Task<Void, Never>?
    private var preparedAssetLocale = ""
    private var reservedModernLocale: Locale?
    @Published private(set) var modernReady = false
    @Published private(set) var recognitionEngine = "Apple speech"
    @Published private(set) var engineMessage = ""
    private var cachedRecognizer: SFSpeechRecognizer?
    private var cachedLocale = ""
    @Published var microphoneStarting = false
    @Published var timing = ""
    private var captureStartedAt: TimeInterval = 0
    private var releasedAt: TimeInterval = 0
    private var resolvedAt: TimeInterval = 0
    private var startupMS = 0
    private func now() -> TimeInterval { ProcessInfo.processInfo.systemUptime }
    private func recognizer() -> SFSpeechRecognizer? {
        if cachedRecognizer == nil || cachedLocale != settings.locale {
            cachedLocale = settings.locale
            cachedRecognizer = SFSpeechRecognizer(locale: Locale(identifier: settings.locale))
        }
        return cachedRecognizer
    }
    private var transcriptBuffer = TranscriptBuffer()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var timer: Timer?
    private var finalTimeout: Task<Void, Never>?
    private var networkTask: Task<Void, Never>?
    private var finalizing = false
    private var insertionStarted = false
    private var panel: NSPanel?
    private var startedAt = Date()
    private var cloud = CloudService()
    var busy: Bool { lifecycle.phase != .idle }
    var recording: Bool { lifecycle.phase == .recording }
    var shortcutLabel: String { DictationHotkey.choices.first(where: { $0.0 == settings.shortcut })?.1 ?? "Choose a shortcut" }
    var onDeviceSupported: Bool { modernReady || recognizer()?.supportsOnDeviceRecognition == true }
    override init() {
        super.init()
        refreshPermissions()
        // Remove only this feature's abandoned temporary recordings after a crash.
        let folder = audioFolder
        if let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) {
            for url in files where url.pathExtension == "m4a" { try? FileManager.default.removeItem(at: url) }
        }
        hotkey.onArm = { [weak self] in self?.armIndicator() }
        hotkey.onDisarm = { [weak self] in self?.hideIndicator() }
        hotkey.onPress = { [weak self] in self?.begin() }
        hotkey.onCancel = { [weak self] in self?.cancel() }
        hotkey.onRelease = { [weak self] in self?.finish() }
        configureHotkey(); prepareModernAssets()
        let permissionTimer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in guard let self, !self.busy else { return }; self.refreshPermissions() }
        }
        self.permissionTimer = permissionTimer; RunLoop.main.add(permissionTimer, forMode: .common)
        DispatchQueue.main.async { [weak self] in self?.updateIndicator() }
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(sleeping), name: NSWorkspace.willSleepNotification, object: nil)
    }
    private var audioFolder: URL { DoclinPaths.support.appendingPathComponent("dictation-audio") }
    func refreshPermissions() {
        let microphone = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        let speech = SFSpeechRecognizer.authorizationStatus() == .authorized
        let accessibility = AXIsProcessTrusted()
        if microphoneGranted != microphone { microphoneGranted = microphone }
        if speechGranted != speech { speechGranted = speech }
        if accessibilityGranted != accessibility { accessibilityGranted = accessibility }
        if settings.enabled && settings.shortcut == "right-command" && accessibilityGranted != shortcutReady { configureHotkey() }
        updateIndicator()
    }
    func requestMicrophone() {
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] _ in Task { @MainActor in self?.refreshPermissions() } }
    }
    func requestSpeech() {
        SFSpeechRecognizer.requestAuthorization { [weak self] _ in Task { @MainActor in self?.refreshPermissions() } }
    }
    func openAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    func openMicrophoneSettings() { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!) }
    func openSpeechSettings() { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition")!) }
    func saveSettings() {
        cancel(showMessage: false)
        do { try settings.save() } catch { message = "Could not save dictation settings." }
        configureHotkey(); refreshPermissions(); prepareModernAssets()
    }
    private func prepareModernAssets(force: Bool = false) {
        let signature = [settings.provider, settings.locale, String(settings.enabled), settings.vocabulary].joined(separator: "|")
        guard force || preparedAssetLocale != signature else { return }
        preparedAssetLocale = signature
        if #available(macOS 26.0, *), let session = preparedModernSession as? ModernDictation { session.cancel() }
        preparedModernSession = nil
        let previousTask = assetTask
        previousTask?.cancel(); modernReady = false
        recognitionEngine = "Apple speech"
        guard #available(macOS 26.0, *) else { engineMessage = ""; return }
        let identifier = settings.locale, enabled = settings.enabled, provider = settings.provider, terms = settings.terms
        engineMessage = enabled && provider == "local" ? "Preparing enhanced on-device recognition…" : ""
        assetTask = Task { [weak self] in
            // Serialize reservations across canceled preparation tasks/language changes.
            await previousTask?.value
            guard !Task.isCancelled, let self else { return }
            guard enabled, provider == "local", SpeechTranscriber.isAvailable,
                  let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: identifier)) else {
                if let previous = self.reservedModernLocale { _ = await AssetInventory.release(reservedLocale: previous); self.reservedModernLocale = nil }
                if enabled && provider == "local" { self.engineMessage = "Enhanced recognition is unavailable for this language; using Apple speech." }
                return
            }
            do {
                try Task.checkCancellation()
                if let previous = self.reservedModernLocale, previous.identifier != locale.identifier {
                    _ = await AssetInventory.release(reservedLocale: previous); self.reservedModernLocale = nil
                }
                try Task.checkCancellation()
                _ = try await AssetInventory.reserve(locale: locale)
                self.reservedModernLocale = locale
                try Task.checkCancellation()
                let transcriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
                if await AssetInventory.status(forModules: [transcriber]) != .installed {
                    self.engineMessage = "Downloading the on-device speech model. Audio stays on your Mac."
                    if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) { try await request.downloadAndInstall() }
                }
                try Task.checkCancellation()
                let session = try await ModernDictation.prepare(locale: locale, terms: terms) { _ in }
                guard !Task.isCancelled else { session.cancel(); return }
                self.preparedModernSession = session; self.modernReady = true
                self.recognitionEngine = "Enhanced Apple speech"
                self.engineMessage = "Enhanced streaming recognition is ready. Audio stays on your Mac."
            } catch {
                guard !Task.isCancelled else { return }
                self.modernReady = false; self.preparedAssetLocale = ""
                self.engineMessage = "Enhanced model unavailable. Using Apple speech; change language to retry."
            }
        }
    }
    private func configureHotkey() {
        hotkey.unregister(); shortcutReady = false
        if settings.enabled {
            shortcutReady = hotkey.register(settings.shortcut)
            if !shortcutReady { message = settings.shortcut == "right-command" ? "Allow Accessibility, then click Refresh to enable Right Command." : "That shortcut is unavailable. Choose another; another app may already use it." }
        }
    }
    func begin(inApp: Bool = false) {
        guard !busy else { return }
        stopIndicatorPreview()
        hudPresented = true; indicatorArmed = true; showHUD()
        refreshPermissions()
        guard settings.enabled else { hideIndicator(); message = "Enable dictation first."; openSettings(); return }
        guard microphoneGranted else { message = "Allow Microphone in Dictation settings, then press the shortcut again."; phase = "Microphone needed"; hideIndicator(); openSettings(); return }
        if settings.provider == "local" {
            guard modernReady || speechGranted else { message = "Allow Speech Recognition in Dictation settings first."; phase = "Speech permission needed"; hideIndicator(); openSettings(); return }
            guard onDeviceSupported else { message = "On-device recognition is unavailable for this language on this Mac. Choose another language or OpenAI transcription."; phase = "Language unavailable"; hideIndicator(); openSettings(); return }
        } else if keyProvider() == nil {
            message = "Add your OpenAI API key in Settings → Cloud, or choose On this Mac."; phase = "API key needed"; hideIndicator(); openSettings(); return
        }
        guard let ticket = lifecycle.begin() else { return }
        captureStartedAt = now(); releasedAt = 0; resolvedAt = 0; timing = ""; microphoneStarting = true
        target = inApp ? nil : insertion.capture()
        targetName = target?.app.localizedName ?? "Doclin"
        partial = ""; seconds = 0; level = 0; finalizing = false; insertionStarted = false; startedAt = Date()
        indicatorArmed = false
        phase = "Listening"; message = inApp ? "Speak, then click Finish." : "Release \(shortcutLabel) to finish."
        onBusyChange(true); showHUD()
        do {
            if settings.provider == "local" {
                if #available(macOS 26.0, *), modernReady { startModern(ticket) }
                else { try startLocal(ticket) }
            } else { try startCloudRecording() }
            let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in Task { @MainActor in self?.tick() } }
            self.timer = timer; RunLoop.main.add(timer, forMode: .common)
        } catch { fail("Could not start the microphone: \(error.localizedDescription)", ticket: ticket) }
    }
    private func startLocal(_ ticket: UUID) throws {
        guard let recognizer = recognizer(), recognizer.isAvailable else { throw DictationError.unavailable }
        transcriptBuffer = TranscriptBuffer()
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.taskHint = .dictation
        request.requiresOnDeviceRecognition = true; request.shouldReportPartialResults = true; request.addsPunctuation = true
        request.contextualStrings = settings.terms
        recognitionRequest = request
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            let text = result?.bestTranscription.formattedString
            let final = result?.isFinal == true
            let utteranceComplete = final || result?.speechRecognitionMetadata != nil
            let utteranceStart = result?.speechRecognitionMetadata?.speechStartTimestamp
            let errorMessage = error?.localizedDescription
            Task { @MainActor in
                guard let self, self.lifecycle.accepts(ticket), !self.finalizing else { return }
                if let text { self.partial = self.transcriptBuffer.update(text, completedUtterance: utteranceComplete, start: utteranceStart) }
                if final {
                    self.stopCapture(); _ = self.lifecycle.finishRecording(); self.resolve(self.partial, ticket: ticket)
                } else if let errorMessage {
                    self.stopCapture(); _ = self.lifecycle.finishRecording()
                    if !self.partial.isEmpty { self.message = "Recognition ended early. Review the transcript."; self.target = nil; self.resolve(self.partial, ticket: ticket) }
                    else { self.fail("No transcript: \(errorMessage)", ticket: ticket) }
                }
            }
        }
        let stream = DictationAudioStream(request)
        startCapture(stream, ticket: ticket)
    }
    private func startCapture(_ stream: any DictationAudioSink, ticket: UUID) {
        captureStream = stream
        capture.start(stream: stream, level: { [weak self] value in
            Task { @MainActor in
                guard let self, self.lifecycle.accepts(ticket), self.recording else { return }
                self.level = value
            }
        }, completion: { [weak self] error in
            Task { @MainActor in
                guard let self, self.lifecycle.accepts(ticket), self.recording else { return }
                if let error { self.fail("Could not start the microphone: \(error)", ticket: ticket); return }
                self.microphoneStarting = false
                if self.startSoundEnabled { self.startCue.play() }
                self.startupMS = Int((self.now() - self.captureStartedAt) * 1000)
                self.timing = "Microphone ready: \(self.startupMS) ms"
                self.updateIndicator()
            }
        })
    }
    @available(macOS 26.0, *)
    private func startModern(_ ticket: UUID) {
        if let session = preparedModernSession as? ModernDictation {
            preparedModernSession = nil; modernSession = session
            session.onUpdate = { [weak self] text in
                guard let self, self.lifecycle.accepts(ticket), !self.finalizing else { return }
                self.partial = text
            }
            startCapture(session.stream, ticket: ticket)
            return
        }
        preparationTask = Task { [weak self] in
            guard let self else { return }
            do {
                let session = try await ModernDictation.prepare(locale: Locale(identifier: self.settings.locale), terms: self.settings.terms) { [weak self] text in
                    guard let self, self.lifecycle.accepts(ticket), !self.finalizing else { return }
                    self.partial = text
                }
                guard !Task.isCancelled, self.lifecycle.accepts(ticket), self.recording else { session.cancel(); return }
                self.modernSession = session
                self.startCapture(session.stream, ticket: ticket)
            } catch {
                guard !Task.isCancelled, self.lifecycle.accepts(ticket), self.recording else { return }
                self.modernReady = false; self.preparedAssetLocale = ""
                self.recognitionEngine = "Apple speech"
                self.engineMessage = "Enhanced recognition could not start. Using standard Apple speech."
                if self.speechGranted, self.recognizer()?.supportsOnDeviceRecognition == true {
                    do { try self.startLocal(ticket) }
                    catch { self.fail("Could not start on-device recognition. Try again.", ticket: ticket) }
                } else {
                    self.fail("Enhanced recognition could not start. Allow Speech Recognition to use the fallback.", ticket: ticket)
                }
            }
        }
    }
    private func startCloudRecording() throws {
        try FileManager.default.createDirectory(at: audioFolder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let url = audioFolder.appendingPathComponent(UUID().uuidString + ".m4a"); recordingURL = url
        let recorder = try AVAudioRecorder(url: url, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 24000, AVNumberOfChannelsKey: 1, AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue])
        self.recorder = recorder; recorder.isMeteringEnabled = true
        guard recorder.prepareToRecord() else { throw DictationError.unavailable }
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        guard recorder.record() else { throw DictationError.unavailable }
        microphoneStarting = false; if startSoundEnabled { startCue.play() }; startupMS = Int((now() - captureStartedAt) * 1000)
    }
    private func tick() {
        guard recording else { return }
        seconds = Int(Date().timeIntervalSince(startedAt))
        if let recorder { recorder.updateMeters(); level = min(1, pow(10, recorder.averagePower(forChannel: 0) / 20) * 5) }
        if seconds >= (modernSession != nil ? 300 : settings.provider == "local" ? 55 : 90) { finish() }
    }
    func finish() {
        hideIndicator()
        guard lifecycle.finishRecording(), let ticket = lifecycle.ticket else { return }
        releasedAt = now()
        if microphoneStarting && captureStream == nil {
            preparationTask?.cancel(); preparationTask = nil
            fail("Recording stopped before the microphone was ready. Wait for the start sound before speaking.", ticket: ticket)
            return
        }
        stopCapture(); phase = "Transcribing"; message = "Turning your voice into text…"
        if #available(macOS 26.0, *), let session = modernSession as? ModernDictation {
            finalTimeout = Task { [weak self] in
                do { try await Task.sleep(nanoseconds: 8_000_000_000) } catch { return }
                guard let self, self.lifecycle.accepts(ticket), !self.finalizing else { return }
                session.cancel(); self.modernSession = nil; self.target = nil
                self.message = "Recognition took too long. Review the available transcript."
                self.resolve(self.partial, ticket: ticket)
            }
            networkTask = Task { [weak self] in
                guard let self else { return }
                do {
                    let text = try await session.finish()
                    guard !Task.isCancelled, self.lifecycle.accepts(ticket), !self.finalizing else { return }
                    self.modernSession = nil; self.resolve(text, ticket: ticket)
                } catch {
                    guard !Task.isCancelled, self.lifecycle.accepts(ticket), !self.finalizing else { return }
                    session.cancel(); self.modernSession = nil; self.target = nil
                    self.message = "Recognition ended early. Review the available transcript."
                    self.resolve(self.partial, ticket: ticket)
                }
            }
        } else if settings.provider == "local" {
            // stopCapture sealed the stream before queuing device teardown.
            // Final recognition can proceed while the audio device stops.
            finalTimeout = Task { [weak self] in
                do { try await Task.sleep(nanoseconds: 6_000_000_000) } catch { return }
                guard let self, self.lifecycle.accepts(ticket), !self.finalizing else { return }
                self.target = nil; self.message = "Recognition took too long. Review the available transcript."
                self.resolve(self.partial, ticket: ticket)
            }
        } else {
            guard let url = recordingURL, let key = keyProvider() else { fail("Recording unavailable. Try again.", ticket: ticket); return }
            networkTask = Task { [weak self] in
                guard let self, self.lifecycle.accepts(ticket), !Task.isCancelled else { return }
                do {
                    let audio = try Data(contentsOf: url)
                    self.deleteRecording()
                    let text = try await self.cloud.transcribe(audio: audio, key: key, locale: self.settings.locale, terms: self.settings.terms)
                    guard self.lifecycle.accepts(ticket), !Task.isCancelled else { return }
                    self.resolve(text, ticket: ticket)
                } catch { if self.lifecycle.accepts(ticket), !Task.isCancelled { self.fail("Transcription failed. \(error.localizedDescription)", ticket: ticket) } }
            }
        }
    }
    private func resolve(_ raw: String, ticket: UUID) {
        guard lifecycle.accepts(ticket), !finalizing else { return }
        hideIndicator()
        resolvedAt = now()
        finalizing = true; finalTimeout?.cancel(); finalTimeout = nil
        recognitionTask?.cancel(); recognitionTask = nil; recognitionRequest = nil
        let raw = DictationText.normalized(raw)
        guard !raw.isEmpty else { fail("No speech was recognized. Check the microphone and try again.", ticket: ticket); return }
        history.record(id: ticket, text: raw, original: raw, destination: targetName, timestamp: startedAt)
        networkTask = Task { [weak self] in
            guard let self, self.lifecycle.accepts(ticket), !Task.isCancelled else { return }
            var result = raw
            if self.settings.cleanup, let key = self.keyProvider() {
                self.phase = "Cleaning up"
                self.history.setState(ticket, state: "Cleaning up")
                do { result = try await self.cloud.cleanDictation(raw, key: key) }
                catch { if self.lifecycle.accepts(ticket) { self.message = "Cleanup was unavailable. Kept your original words." } }
            }
            guard self.lifecycle.accepts(ticket), !Task.isCancelled else { return }
            self.originalTranscript = raw; self.transcript = result
            self.history.applyResult(ticket, text: result)
            self.insertionStarted = self.settings.autoInsert && self.target != nil
            let outcome: TextInsertion.Result = self.settings.autoInsert ? await self.insertion.insert(result, into: self.target, allowClipboard: self.settings.clipboardFallback) : .retained
            guard !Task.isCancelled, self.lifecycle.complete(ticket) else { return }
            switch outcome {
            case .inserted: self.phase = "Inserted"; self.message = "Inserted into \(self.targetName). Nothing was sent."
            case .pasted: self.phase = "Paste requested"; self.message = "Paste requested in \(self.targetName). Your transcript is also here if the app did not accept it."
            case .retained: self.phase = "Text ready"; self.message = "Could not confirm insertion into the original field. Your transcript is kept below; copy it if needed."
            }
            self.history.setState(ticket, state: self.phase)
            if self.releasedAt > 0 {
                let recognitionMS = Int((self.resolvedAt - self.releasedAt) * 1000)
                let insertionMS = Int((self.now() - self.resolvedAt) * 1000)
                self.timing = "Mic: \(self.startupMS) ms · Final text: \(recognitionMS) ms · Cleanup/insertion: \(insertionMS) ms"
            }
            self.target = nil; self.level = 0; self.onBusyChange(false); self.dismissHUDLater()
            if self.preparedModernSession == nil { self.prepareModernAssets(force: true) }
        }
    }
    private func stopCapture() {
        timer?.invalidate(); timer = nil
        captureStream?.endAudio(); captureStream = nil
        capture.stop(); microphoneStarting = false
        recorder?.stop(); recorder = nil; level = 0
    }
    private func deleteRecording() { if let recordingURL { try? FileManager.default.removeItem(at: recordingURL) }; recordingURL = nil }
    private func fail(_ reason: String, ticket: UUID) {
        guard lifecycle.accepts(ticket) else { return }
        cancel(showMessage: false); phase = "Needs attention"; message = reason; dismissHUDLater()
    }
    func cancel(showMessage: Bool = true) {
        hideIndicator(); startCue.stop()
        if let id = lifecycle.ticket { history.setState(id, state: "Text retained") }
        lifecycle.cancel(); finalizing = false
        preparationTask?.cancel(); preparationTask = nil
        if #available(macOS 26.0, *), let session = modernSession as? ModernDictation { session.cancel() }
        modernSession = nil
        if preparedModernSession == nil { prepareModernAssets(force: true) }
        stopCapture(); recognitionTask?.cancel(); recognitionTask = nil; recognitionRequest = nil
        finalTimeout?.cancel(); finalTimeout = nil; networkTask?.cancel(); networkTask = nil
        deleteRecording(); target = nil; partial = ""; phase = showMessage ? "Canceled" : "Ready"; onBusyChange(false)
        if showMessage { showHUD(); dismissHUDLater() } else { updateIndicator() }
        if showMessage { message = insertionStarted ? "Dictation stopped. Insertion had already started; check the destination field." : "Dictation canceled. No text was inserted." }
    }
    func testInsertion() {
        guard !busy, let ticket = lifecycle.begin() else { return }
        _ = lifecycle.finishRecording()
        insertionStarted = false
        phase = "Testing insertion"; onBusyChange(true)
        networkTask = Task { [weak self] in
            guard let self else { return }
            for remaining in (1...8).reversed() {
                self.message = "Click an empty text field in another app. Insertion test in \(remaining)s. No microphone recording."
                do { try await Task.sleep(nanoseconds: 1_000_000_000) } catch { return }
            }
            guard self.lifecycle.accepts(ticket), !Task.isCancelled else { return }
            let target = self.insertion.capture()
            guard let target, target.value.isEmpty, target.selection.location == 0, target.selection.length == 0 else {
                guard self.lifecycle.complete(ticket) else { return }
                self.phase = "Text ready"; self.message = "Test skipped: click an empty text field in another app. Nothing was changed."
                self.onBusyChange(false); self.dismissHUDLater(); return
            }
            self.insertionStarted = true
            self.targetName = target.app.localizedName ?? "Text field"
            let result = await self.insertion.insert("Doclin insertion test.", into: target, allowClipboard: self.settings.clipboardFallback)
            guard !Task.isCancelled, self.lifecycle.complete(ticket) else { return }
            switch result {
            case .inserted: self.phase = "Inserted"; self.message = "Test text verified in \(self.targetName). Nothing was sent."
            case .pasted: self.phase = "Paste requested"; self.message = "Paste sent to \(self.targetName), but the field did not confirm the text."
            case .retained: self.phase = "Text ready"; self.message = "The original field changed or did not accept insertion."
            }
            self.onBusyChange(false); self.dismissHUDLater()
        }
    }
    func copyTranscript() { copyText(transcript) }
    func copyText(_ text: String) {
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text, forType: .string)
        message = "Transcript copied. Paste it wherever you like."
    }
    func clearHistory() { guard !busy else { return }; history.clear(); clearTranscript() }
    func editHistory(_ id: UUID, text: String) {
        guard !busy else { return }
        history.edit(id, text: text)
        if history.entries.first?.id == id { transcript = text }
    }
    func clearTranscript() { transcript = ""; originalTranscript = ""; partial = "" }
    @objc private func sleeping() { cancel() }
    func shutdown() {
        settings.enabled = false
        if #available(macOS 26.0, *), let session = preparedModernSession as? ModernDictation { session.cancel() }
        preparedModernSession = nil
        permissionTimer?.invalidate(); permissionTimer = nil; stopIndicatorPreview(); cancel(showMessage: false); hotkey.unregister(); panel?.orderOut(nil); NSWorkspace.shared.notificationCenter.removeObserver(self) }
    func indicatorAction() {
        if indicatorPreview { stopIndicatorPreview(); return }
        if indicatorArmed && !recording { hotkey.cancelPendingHold(); hideIndicator() }
        else if recording { finish() }
        else if indicatorState == .setup || indicatorState == .error || !settings.enabled { openSettings() }
        else if !busy { begin() }
    }
    private func armIndicator() {
        guard settings.enabled, !busy else { return }
        stopIndicatorPreview()
        partial = ""; seconds = 0; level = 0
        indicatorArmed = true; hudPresented = true; showHUD()
    }
    private func hideIndicator() {
        hudPresented = false
        panel?.orderOut(nil)
        indicatorArmed = false
    }
    func setStartSound(_ enabled: Bool) {
        startSoundEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "dictationStartSound")
        if !enabled { startCue.stop() }
    }
    func dismissIndicator() {
        if indicatorPreview { stopIndicatorPreview() }
        else if busy { cancel() }
        else { hotkey.cancelPendingHold(); hideIndicator() }
    }
    func previewIndicator() {
        guard !busy else { return }
        stopIndicatorPreview(); indicatorPreview = true
        previewTask = Task { [weak self] in
            guard let self else { return }
            for state in [DictationIndicatorState.listening] {
                guard !Task.isCancelled else { return }
                self.previewState = state; self.showHUD()
                do { try await Task.sleep(nanoseconds: 3_000_000_000) } catch { return }
            }
            self.stopIndicatorPreview()
        }
    }
    private func stopIndicatorPreview() {
        previewTask?.cancel(); previewTask = nil; indicatorPreview = false; updateIndicator()
    }
    private func updateIndicator() {
        if hudPresented || indicatorPreview { showHUD(reposition: false) }
        else { panel?.orderOut(nil) }
    }
    private func showHUD(reposition: Bool = true) {
        guard hudPresented || indicatorPreview else { return }
        if panel == nil {
            let p = DictationPanel(contentRect: NSRect(x: 0, y: 0, width: indicatorWidth, height: indicatorHeight), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            p.title = "Doclin Dictation"
            p.isFloatingPanel = true; p.level = .floating; p.hidesOnDeactivate = false; p.isOpaque = false; p.backgroundColor = .clear; p.hasShadow = true
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            p.contentView = DictationHUDHost(rootView: DictationHUD(controller: self)); panel = p
        }
        guard let panel else { return }
        let screen = (!reposition ? panel.screen : nil) ?? NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? NSScreen.main
        if let frame = screen?.visibleFrame {
            let rect = NSRect(x: frame.midX - indicatorWidth / 2, y: frame.minY + 18, width: indicatorWidth, height: indicatorHeight)
            if panel.frame != rect { panel.setFrame(rect, display: true) }
        }
        if !panel.isVisible { panel.orderFrontRegardless() }
    }
    private func dismissHUDLater() {
        let token = hudGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self, !self.busy, self.hudGeneration == token else { return }
            self.phase = "Ready"; self.updateIndicator()
        }
    }
    enum DictationError: LocalizedError {
        case unavailable
        var errorDescription: String? { "The microphone or speech recognizer is unavailable." }
    }
}
