//
//  AppDelegate.swift
//  Amaris
//
//  Lets Amaris live quietly in the background:
//  - opens at login (without a window) so Goodreads keeps syncing
//  - shows a Dock icon only while a window is open; the menu bar icon stays
//  - syncs again after the Mac wakes up
//

import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Owned here (not by a window) so syncing runs with no window open.
    let model = AppModel()

    func applicationWillFinishLaunching(_ notification: Notification) {
        let event = NSAppleEventManager.shared().currentAppleEvent
        model.launchedAtLogin = event?.eventID == kAEOpenApplication
            && event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        LoginItem.enableOnFirstLaunch()
        model.startBackgroundSync()

        let center = NotificationCenter.default
        center.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateDockIcon() }
        }
        center.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { [weak self] _ in
            // The closing window is still visible now; check once it's gone.
            Task { @MainActor in self?.updateDockIcon() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.model.syncAfterWake() }
        }
    }

    /// Closing the last window keeps Amaris running for sync and the menu bar.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func updateDockIcon() {
        let hasWindow = NSApp.windows.contains { $0.isVisible && $0.canBecomeMain && !($0 is NSPanel) }
        let policy: NSApplication.ActivationPolicy = hasWindow ? .regular : .accessory
        guard NSApp.activationPolicy() != policy else { return }
        NSApp.setActivationPolicy(policy)
        if hasWindow { NSApp.activate() }
    }
}

/// "Open at login", using macOS's Login Items (System Settings → General → Login Items).
enum LoginItem {
    private static let didSetUpKey = "didSetUpLoginItem"

    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    /// Needs switching on in System Settings before it takes effect.
    static var needsApproval: Bool { SMAppService.mainApp.status == .requiresApproval }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    /// On by default; after the first launch it's whatever was chosen in Settings.
    static func enableOnFirstLaunch() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: didSetUpKey) else { return }
        defaults.set(true, forKey: didSetUpKey)
        try? setEnabled(true)
    }
}
