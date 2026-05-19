import AppKit
import SwiftUI
import SuiteKit

/// Stats as a SuiteKit pane. Owns the store, vends the dashboard,
/// and reproduces the rasterised menu-bar widget every tick so the
/// standalone glyph is unchanged (and the launcher gets a live
/// segment image too).
@MainActor
public final class StatsPaneProvider: NSObject, SuitePane {
    private let store = StatsStore()

    /// Standalone shim / host segment: fired each tick with the
    /// freshly rendered status image.
    public var onMenuBarImageChange: ((NSImage) -> Void)?

    public override init() {
        super.init()
        store.onTick = { [weak self] in
            guard let self else { return }
            self.onMenuBarImageChange?(self.render())
        }
    }

    public var suiteABIVersion: Int { SuiteKitABI.current }
    public var paneID: String { "stats" }
    public var paneTitle: String { "STATS" }
    public var paneTintHex: String { "#7C83FF" }

    /// The switcher segment / idle glyph is always the clean
    /// heartbeat line — NOT the rasterised widget row (which is
    /// illegible at segment size). The standalone status item still
    /// gets the live widget render via `onMenuBarImageChange`.
    public func paneMenuBarImage() -> NSImage { Self.heartbeat }

    private static let heartbeat: NSImage = {
        let img = NSImage(
            systemSymbolName: "waveform.path.ecg",
            accessibilityDescription: "Stats") ?? NSImage()
        img.isTemplate = true
        return img
    }()

    public func paneMakeView() -> NSView {
        NSHostingView(rootView: ContentView().environment(store))
    }

    public func paneStart() {
        store.start()
        onMenuBarImageChange?(render())
    }

    public func paneStop() {
        // Sampler poll is harmless to leave running.
    }

    /// Same logic as the old AppDelegate.refreshStatusItem: a plain
    /// template glyph when only the icon widget is on, otherwise the
    /// rasterised widget row.
    private func render() -> NSImage {
        func fallback() -> NSImage { Self.heartbeat }
        if store.menuBar.widgets == [.icon] { return fallback() }
        let renderer = ImageRenderer(
            content: MenuBarWidgetView(store: store))
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        if let img = renderer.nsImage {
            img.isTemplate = false
            return img
        }
        return fallback()
    }
}

@_cdecl("suitePaneCreate")
public func suitePaneCreate() -> Unmanaged<AnyObject> {
    MainActor.assumeIsolated {
        Unmanaged.passRetained(StatsPaneProvider())
    }
}
