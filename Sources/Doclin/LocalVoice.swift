import Foundation
import DoclinCore

/// One disposable, offline synthesis process per short notification.
@MainActor final class LocalVoice {
    static var available: Bool {
        #if arch(x86_64)
        if #unavailable(macOS 15.5) { return false }
        #endif
        return FileManager.default.isExecutableFile(atPath: helper.path)
            && FileManager.default.fileExists(atPath: model.appendingPathComponent("model.int8.onnx").path)
    }
    private static var helper: URL { Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/doclin-voice") }
    private static var model: URL { Bundle.main.resourceURL!.appendingPathComponent("VoiceModel") }
    private var process: Process?
    init() {
        // Private scratch audio left by a crash is never retained across launches.
        let fm = FileManager.default
        let folder = DoclinPaths.support.appendingPathComponent("voice-audio")
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        for file in (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? [] { try? fm.removeItem(at: file) }
    }
    func synthesize(_ text: String, rate: Double) async throws -> Data {
        try Task.checkCancellation()
        guard Self.available, process == nil else { throw CloudService.CloudError.invalidResponse }
        let directory = DoclinPaths.support.appendingPathComponent("voice-audio").appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let output = directory.appendingPathComponent("speech.wav")
        let task = Process(), input = Pipe()
        task.executableURL = Self.helper
        task.arguments = [Self.model.path, output.path, String(min(1.5, max(0.8, rate)))]
        task.standardInput = input; task.standardOutput = FileHandle.nullDevice; task.standardError = FileHandle.nullDevice
        process = task
        defer { if process === task { process = nil }; try? FileManager.default.removeItem(at: directory) }
        return try await withTaskCancellationHandler {
            let bytes: Data = try await withCheckedThrowingContinuation { continuation in
                task.terminationHandler = { task in
                    Task { @MainActor in
                        guard task.terminationStatus == 0, let data = try? Data(contentsOf: output), data.count > 44 else {
                            continuation.resume(throwing: CloudService.CloudError.invalidResponse); return
                        }
                        continuation.resume(returning: data)
                    }
                }
                var launched = false
                do {
                    try task.run(); launched = true
                    try input.fileHandleForWriting.write(contentsOf: Data(text.prefix(500).utf8))
                    try input.fileHandleForWriting.close()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self, weak task] in
                        guard let task, task.isRunning else { return }; self?.stop(task)
                    }
                } catch {
                    // Once launched, completion belongs to terminationHandler only.
                    try? input.fileHandleForWriting.close()
                    if launched { stop(task) }
                    else { task.terminationHandler = nil; continuation.resume(throwing: error) }
                }
            }
            try Task.checkCancellation()
            return bytes
        } onCancel: {
            Task { @MainActor [weak self] in self?.stop(task) }
        }
    }
    private func stop(_ task: Process) {
        guard task.isRunning else { return }
        task.terminate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak task] in
            guard let task, task.isRunning else { return }; kill(task.processIdentifier, SIGKILL)
        }
    }
}
