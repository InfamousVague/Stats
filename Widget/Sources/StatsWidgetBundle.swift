import WidgetKit
import SwiftUI

/// `@main` for the Stats widget extension. The bundle is what
/// WidgetKit enumerates to populate the macOS widget gallery;
/// adding another widget later (per-sensor / per-volume / etc.)
/// means just appending another entry inside `body`.
@main
struct StatsWidgetBundle: WidgetBundle {
    var body: some Widget {
        StatsLiveWidget()
    }
}
