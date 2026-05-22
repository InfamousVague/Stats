import Foundation

/// Shared App Group id used by both the Stats host (pane + standalone)
/// AND the widget extension to point at the same Group Container —
/// where `SharedStats` is written each sampling tick and read by the
/// widget's timeline provider.
///
/// Must match `StatsWidgets.entitlements`'
/// `com.apple.security.application-groups` entry and the host's
/// `com.apple.security.application-groups`; drift between the two
/// silently produces an empty Group Container URL and the widget
/// reads stale defaults.
public enum AppGroup {
    public static let id =
        "F6ZAL7ANAD.group.com.mattssoftware.stats"

    /// Container URL macOS hands out for our App Group, or nil if the
    /// entitlement isn't grants (sandbox + groups missing in this
    /// process). Both producer (host) and consumer (widget) use the
    /// same path inside this dir.
    public static var containerURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: id)
    }
}
