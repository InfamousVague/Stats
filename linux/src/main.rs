//! Linux build of Stats. Scaffold only — see ../README.md for the
//! per-signal /proc & /sys source map and the implementation plan.
//!
//! Real version: pure-Rust sampler over /proc + /sys + lm-sensors,
//! a `ksni` tray icon mirroring the macOS widget choices, and a
//! GTK4 panel with the same sparkline layout.

fn main() {
    eprintln!(
        "stats (linux): scaffold only — see linux/README.md for \
         the implementation plan."
    );
    std::process::exit(0);
}
