import Carbon
import Foundation
import AppKit
import ApplicationServices
import DoclinCore

/// Modifier monitoring is passive; key contents are never read or stored.
@MainActor final class DictationHotkey {
    private var hotkey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    var onArm: (() -> Void)?
    var onDisarm: (() -> Void)?
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?
    private var held = false
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var activation: DispatchWorkItem?
    private var rightCommand = ModifierHold()
    private var ownsIndicator = false
    var onCancel: (() -> Void)?
    static let choices = [("right-command", "Right ⌘", UInt32(54), UInt32(0)), ("control-option-space", "⌃ ⌥ Space", UInt32(kVK_Space), UInt32(controlKey | optionKey)), ("control-shift-space", "⌃ ⇧ Space", UInt32(kVK_Space), UInt32(controlKey | shiftKey)), ("command-shift-d", "⌘ ⇧ D", UInt32(kVK_ANSI_D), UInt32(cmdKey | shiftKey))]
    func register(_ choice: String) -> Bool {
        unregister()
        if choice == "right-command" { return registerRightCommand() }
        guard let selected = Self.choices.first(where: { $0.0 == choice }) else { return false }
        var types = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)), EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))]
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        let result = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            return MainActor.assumeIsolated {
                let owner = Unmanaged<DictationHotkey>.fromOpaque(context).takeUnretainedValue()
                var id = EventHotKeyID()
                guard GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id) == noErr, id.signature == 0x444F434C else { return OSStatus(eventNotHandledErr) }
                if GetEventKind(event) == kEventHotKeyPressed {
                    if !owner.held { owner.held = true; owner.onPress?() }
                } else { owner.held = false; owner.onRelease?() }
                return noErr
            }
        }, types.count, &types, pointer, &handler)
        guard result == noErr else { return false }
        let code = RegisterEventHotKey(selected.2, selected.3, EventHotKeyID(signature: 0x444F434C, id: 1), GetApplicationEventTarget(), 0, &hotkey)
        if code != noErr { unregister(); return false }
        return true
    }
    private func registerRightCommand() -> Bool {
        guard AXIsProcessTrusted() else { return false }
        let mask: NSEvent.EventTypeMask = [.flagsChanged, .keyDown]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            MainActor.assumeIsolated { self?.observe(event) }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            MainActor.assumeIsolated { self?.observe(event) }
            return event
        }
        guard globalMonitor != nil, localMonitor != nil else { unregister(); return false }
        return true
    }
    private func observe(_ event: NSEvent) {
        // NX_DEVICERCMDKEYMASK identifies the right key independently of left Command.
        let down = event.modifierFlags.rawValue & 0x10 != 0
        let otherModifiers = !event.modifierFlags.intersection([.shift, .control, .option, .function]).isEmpty
            || event.modifierFlags.rawValue & 0x08 != 0
        if event.type == .keyDown || otherModifiers { activation?.cancel(); activation = nil }
        let action = rightCommand.update(down: down, chord: event.type == .keyDown || otherModifiers)
        switch action {
        case .arm:
            ownsIndicator = true; onArm?()
            let work = DispatchWorkItem { [weak self] in
                guard let self, self.rightCommand.activate() else { return }
                self.onPress?()
            }
            activation = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
        case .release:
            activation?.cancel(); activation = nil; disarmIndicator(); onRelease?()
        case .cancel:
            activation?.cancel(); activation = nil; disarmIndicator(); onCancel?()
        case .none:
            if !down || event.type == .keyDown || otherModifiers { activation?.cancel(); activation = nil; disarmIndicator() }
        }
    }
    private func disarmIndicator() {
        guard ownsIndicator else { return }
        ownsIndicator = false; onDisarm?()
    }
    func cancelPendingHold() {
        activation?.cancel(); activation = nil
        _ = rightCommand.update(down: true, chord: true)
        disarmIndicator()
    }
    func unregister() {
        disarmIndicator()
        if held || rightCommand.isActive { onCancel?() }
        activation?.cancel(); activation = nil
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }; globalMonitor = nil
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }; localMonitor = nil
        rightCommand = ModifierHold()
        if let hotkey { UnregisterEventHotKey(hotkey) }; hotkey = nil
        if let handler { RemoveEventHandler(handler) }; handler = nil
        held = false
    }
}
