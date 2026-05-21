# Stats (Linux)

Linux-native sibling of the macOS Swift build at the repo root. Same
product name and version as the Mac build, **separate native
binary** — they share no code, only the user-facing contract:
"every system signal at a glance, in the bar."

## Status

**Scaffold only.** macOS build is the current shipping artifact;
Linux work lands here incrementally.

## Stack

| Layer                | Choice                                                |
| -------------------- | ----------------------------------------------------- |
| Language             | Rust (2021)                                           |
| Sampling             | `procfs` / direct reads of `/proc` & `/sys`           |
| Convenience crate    | [`sysinfo`](https://docs.rs/sysinfo) (cross-distro)   |
| Sensors              | `lm-sensors` (`/sys/class/hwmon`) or `libsensors-sys` |
| Tray                 | [`ksni`](https://docs.rs/ksni) (StatusNotifierItem)   |
| UI / sparklines      | GTK4 + `cairo` for the panel; `ksni` Pixmap for the menu-bar widget |
| Packaging            | `.deb` (`cargo-deb`) · `.rpm` (`cargo-generate-rpm`) · Flatpak |

## Where each signal comes from

| Signal           | Mac (current)               | Linux                                          |
| ---------------- | --------------------------- | ---------------------------------------------- |
| CPU per-core     | `host_processor_info`       | `/proc/stat` (`cpuN` lines)                    |
| Memory pressure  | `vm_stat` + `sysctl`        | `/proc/meminfo` + `MemAvailable`               |
| Disk R/W         | `IOKit` `IOMatchingService` | `/proc/diskstats`                              |
| Network up/down  | `getifaddrs`                | `/sys/class/net/<iface>/statistics/{rx,tx}_bytes` |
| Sensors          | SMC                         | `/sys/class/hwmon/hwmon*/temp*_input` (lm-sensors) |
| Top processes    | `proc_pidinfo`              | `/proc/<pid>/{stat,status,comm}`               |
| Battery (laptop) | IOPowerSources              | `/sys/class/power_supply/BAT*/`                |

## Honest ceilings

- **Sensor labelling** varies wildly across motherboards — Stats Mac labels (P-cluster / E-cluster CPU) won't map 1:1. We'll fall back to driver names from `lm-sensors`.
- **Wayland tray icons**: GNOME needs the AppIndicator extension; everything else works out of the box.
- **Per-process CPU%** sampling cost on huge process tables can be material — sample every 2 s, not 1 s, on Linux.

## Roadmap

1. Sampler library (pure-Rust, no UI) exposing the same data model the Mac store uses.
2. CLI dump (`stats now`) for quick smoke-testing the sampler.
3. `ksni` tray with the same widget choices as Mac (icon / cpu% / mem% / waveform).
4. GTK4 panel with sparklines + per-core grid.
5. Packaging in CI alongside the macOS `.dmg`.
