import AppKit
import SwiftUI
import DoclinCore

// Hook mode does no UI work, network requests, or agent control. Always fail open.
if CommandLine.arguments.contains("--doclin-hook") {
    let args = CommandLine.arguments
    let index = args.firstIndex(of: "--doclin-hook")!
    let source = args.count > index + 1 ? args[index + 1] : "claude"
    let data: Data
    if source == "codex", args.count > index + 2 { data = Data(args[index + 2].utf8) }
    else {
        var input = Data()
        while input.count < 1_048_576 {
            guard let chunk = try? FileHandle.standardInput.read(upToCount: min(65536, 1_048_576 - input.count)), !chunk.isEmpty else { break }
            input.append(chunk)
        }
        data = input
    }
    if let event = HookParser.parse(data, source: source) { try? DoclinPaths.spool(event) }
    exit(0)
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    var model: AppModel!
    var window: NSWindow!
    var item: NSStatusItem!
    var menuTimer: Timer?
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Finder normally handles this; also protect direct executable launches.
        let bundle = Bundle.main.bundleIdentifier ?? "dev.doclin.app"
        if let existing = NSRunningApplication.runningApplications(withBundleIdentifier: bundle).first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            existing.activate(options: .activateIgnoringOtherApps); NSApp.terminate(nil); return
        }
        // Direct background launches can retain a cached Dock icon. Apply the
        // bundled icon explicitly, using the same artwork as Finder and downloads.
        if let iconURL = Bundle.main.url(forResource: "Doclin", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = icon
        }
        let mainMenu = NSMenu()
        let appMenuRoot = NSMenuItem(); let appMenu = NSMenu()
        let quit = NSMenuItem(title: "Quit Doclin", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenu.addItem(quit); appMenuRoot.submenu = appMenu; mainMenu.addItem(appMenuRoot)
        let editRoot = NSMenuItem(title: "Edit", action: nil, keyEquivalent: ""); let edit = NSMenu(title: "Edit")
        for (label, action, key) in [("Cut", #selector(NSText.cut(_:)), "x"), ("Copy", #selector(NSText.copy(_:)), "c"), ("Paste", #selector(NSText.paste(_:)), "v"), ("Select All", #selector(NSText.selectAll(_:)), "a")] {
            edit.addItem(NSMenuItem(title: label, action: action, keyEquivalent: key))
        }
        editRoot.submenu = edit; mainMenu.addItem(editRoot); NSApp.mainMenu = mainMenu
        model = AppModel()
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 700, height: 620), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        model.dictation.openSettings = { [weak self] in self?.showDictation() }
        window.title = "Doclin"
        window.titlebarAppearsTransparent = true
        window.backgroundColor = NSColor(calibratedRed: 0.965, green: 0.975, blue: 0.99, alpha: 1)
        window.contentView = NSHostingView(rootView: DoclinView(model: model))
        window.minSize = NSSize(width: 640, height: 560)
        window.isReleasedWhenClosed = false; window.center()
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Doclin")
        item.button?.toolTip = "Doclin — short agent updates"
        rebuildMenu()
        menuTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in Task { @MainActor in self?.rebuildMenu() } }
        if !CommandLine.arguments.contains("--background") { showWindow() }
    }
    func rebuildMenu() {
        let menu = NSMenu()
        let title = NSMenuItem(title: model.status, action: nil, keyEquivalent: ""); title.isEnabled = false; menu.addItem(title)
        menu.addItem(.separator())
        for (label, action) in [("Open Doclin", #selector(showWindow)), ("Dictation settings", #selector(showDictation)), ("Cancel dictation", #selector(cancelDictation)), (model.preferences.muted ? "Resume announcements" : "Pause announcements", #selector(toggleMute)), ("Stop playback", #selector(stop)), ("Preview voice", #selector(preview))] {
            let i = NSMenuItem(title: label, action: action, keyEquivalent: ""); i.target = self; menu.addItem(i)
        }
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Doclin", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
        item.button?.image = NSImage(systemSymbolName: model.preferences.muted ? "speaker.slash" : "waveform", accessibilityDescription: "Doclin")
    }
    @objc func showWindow() { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    @objc func showDictation() { model.tab = "Dictation"; showWindow() }
    @objc func cancelDictation() { model.dictation.cancel() }
    @objc func toggleMute() { model.toggleMute(); rebuildMenu() }
    @objc func stop() { model.stopAll() }
    @objc func preview() { model.preview() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showWindow(); return true }
    func applicationWillTerminate(_ notification: Notification) { model?.shutdown() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.setActivationPolicy(.regular)
    app.delegate = delegate
    app.run()
}
