import SwiftUI
import AppKit
import StatsPane
import SuiteKit

// Standalone Stats. Post-split this is just a host shim — samplers,
// store, dashboard and the menu-bar widget renderer live in
// `StatsPane` so the MattsSoftware launcher can load the same code
// out of an installed Stats.app. Behaviour unchanged.
@main
struct StatsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body: some Scene { Settings { EmptyView() } }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let pane = StatsPaneProvider()
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()

    func applicationDidFinishLaunching(_ notification: Notification) {
        SuiteGuard.exitIfDeferring("stats")

        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength)
        statusItem.button?.action = #selector(togglePopover(_:))
        statusItem.button?.target = self
        statusItem.button?.image = pane.paneMenuBarImage()
        pane.onMenuBarImageChange = { [weak self] img in
            self?.statusItem.button?.image = img
        }

        let vc = NSViewController()
        vc.view = pane.paneMakeView()
        popover.behavior = .transient
        popover.contentViewController = vc

        pane.paneStart()
    }

    @objc private func togglePopover(_ sender: Any?) {
        if popover.isShown { popover.performClose(sender) }
        else { showPopover() }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button,
                         preferredEdge: .minY)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    /// `stats://` deep link (other suite apps jump into Stats).
    func application(_ application: NSApplication, open urls: [URL]) {
        showPopover()
    }
}
