import CoreAudio
import AVFoundation

struct AudioRoute: Equatable {
    let uid: String
    let name: String
    static func current() -> AudioRoute? {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var device = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device) == noErr, device != 0 else { return nil }
        func string(_ key: AudioObjectPropertySelector) -> String? {
            var a = AudioObjectPropertyAddress(mSelector: key, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            let pointer = UnsafeMutablePointer<CFString?>.allocate(capacity: 1)
            pointer.initialize(to: nil)
            defer { pointer.deinitialize(count: 1); pointer.deallocate() }
            var n = UInt32(MemoryLayout<CFString?>.size)
            guard AudioObjectGetPropertyData(device, &a, 0, nil, &n, pointer) == noErr else { return nil }
            return pointer.pointee as String?
        }
        guard let uid = string(kAudioDevicePropertyDeviceUID), !uid.isEmpty else { return nil }
        return AudioRoute(uid: uid, name: string(kAudioObjectPropertyName) ?? "Selected output")
    }
    func configure(_ player: AVAudioPlayer) -> Bool {
        player.currentDevice = uid
        return player.prepareToPlay() && player.currentDevice == uid
    }
}

/// Stop the old utterance when macOS switches outputs; never replay it on speakers.
@MainActor final class AudioRouteMonitor {
    var changed: (() -> Void)?
    private var listener: AudioObjectPropertyListenerBlock?
    private var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    init() {
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor in self?.changed?() }
        }
        listener = block
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, block)
    }
    func stop() {
        if let listener { AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, listener) }
        listener = nil
    }
}
