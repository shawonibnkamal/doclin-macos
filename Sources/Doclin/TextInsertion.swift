import AppKit
import ApplicationServices

@MainActor final class TextInsertion {
    struct Target {
        let app: NSRunningApplication
        let element: AXUIElement
        let value: String
        let selection: CFRange
    }
    private func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        AXUIElementSetMessagingTimeout(element, 0.2)
        var value: CFTypeRef?; guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }; return value
    }
    private func focused(_ app: NSRunningApplication) -> AXUIElement? {
        guard let value = attribute(AXUIElementCreateApplication(app.processIdentifier), kAXFocusedUIElementAttribute), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }
    private func selection(_ element: AXUIElement) -> CFRange? {
        guard let raw = attribute(element, kAXSelectedTextRangeAttribute), CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        let value = raw as! AXValue
        guard AXValueGetType(value) == .cfRange else { return nil }
        var range = CFRange(); return AXValueGetValue(value, .cfRange, &range) ? range : nil
    }
    func capture() -> Target? {
        guard AXIsProcessTrusted(), let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier, let element = focused(app),
              attribute(element, kAXSubroleAttribute) as? String != "AXSecureTextField",
              let role = attribute(element, kAXRoleAttribute) as? String, ["AXTextField", "AXTextArea", "AXComboBox"].contains(role) else { return nil }
        guard let value = attribute(element, kAXValueAttribute) as? String, let range = selection(element) else { return nil }
        return Target(app: app, element: element, value: value, selection: range)
    }
    func unchanged(_ target: Target) -> Bool {
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == target.app.processIdentifier,
              let current = focused(target.app), CFEqual(current, target.element),
              attribute(current, kAXSubroleAttribute) as? String != "AXSecureTextField" else { return false }
        guard (attribute(current, kAXValueAttribute) as? String) == target.value,
              let now = selection(current), target.selection.location == now.location, target.selection.length == now.length else { return false }
        return true
    }
    enum Result { case inserted, pasted, retained }
    private func expectedValue(_ text: String, target: Target) -> String? {
        let value = target.value as NSString
        let range = target.selection
        guard range.location >= 0, range.length >= 0, range.location <= value.length,
              range.length <= value.length - range.location else { return nil }
        return value.replacingCharacters(in: NSRange(location: range.location, length: range.length), with: text)
    }
    private func verified(_ expected: String, target: Target) -> Bool {
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == target.app.processIdentifier,
              let current = focused(target.app), CFEqual(current, target.element) else { return false }
        return attribute(current, kAXValueAttribute) as? String == expected
    }
    func insert(_ text: String, into target: Target?, allowClipboard: Bool) async -> Result {
        guard !text.isEmpty, let target, let expected = expectedValue(text, target: target), unchanged(target) else { return .retained }
        // Recognition can finish while the shortcut is still held. Never paste with extra modifiers.
        for _ in 0..<50 {
            guard !Task.isCancelled else { return .retained }
            if NSEvent.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty { break }
            do { try await Task.sleep(nanoseconds: 40_000_000) } catch { return .retained }
        }
        guard !Task.isCancelled, unchanged(target),
              NSEvent.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty else { return .retained }
        var pasteRequested = false
        if allowClipboard {
            // Browser/Electron editors may report a successful AX write without updating their editor.
            // Standard Paste goes through the editor's normal input handling at the saved caret.
            guard let down = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: true),
                  let up = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: false) else { return .retained }
            let board = NSPasteboard.general
            board.clearContents()
            let item = NSPasteboardItem(); item.setString(text, forType: .string)
            item.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
            item.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))
            guard board.writeObjects([item]), unchanged(target), !Task.isCancelled else { return .retained }
            down.flags = .maskCommand; up.flags = .maskCommand
            down.post(tap: .cghidEventTap); up.post(tap: .cghidEventTap)
            pasteRequested = true
        } else {
            var settable = DarwinBoolean(false)
            guard AXUIElementIsAttributeSettable(target.element, kAXSelectedTextAttribute as CFString, &settable) == .success,
                  settable.boolValue, AXUIElementSetAttributeValue(target.element, kAXSelectedTextAttribute as CFString, text as CFString) == .success else { return .retained }
        }
        // A successful API call is not proof of insertion. Read the destination back after it processes input.
        // Never retry a dispatched write: that could duplicate words in a slow editor.
        for _ in 0..<15 {
            do { try await Task.sleep(nanoseconds: 80_000_000) } catch { return .retained }
            guard !Task.isCancelled else { return .retained }
            if verified(expected, target: target) { return .inserted }
        }
        return pasteRequested ? .pasted : .retained
    }
}
