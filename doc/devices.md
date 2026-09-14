# Observed device behaviour

Vendors document almost nothing about what their hinge sensors actually
report. This file records what we have measured on real hardware. Entries come
from `flutter run -t tool/report_device.dart`.

If you own a foldable that is not listed, running that tool and opening an
issue is the single most useful contribution you can make to this package.

---

## Samsung Galaxy Z Flip 5 — `samsung / SM-F731N`

Measured 2026-09-14, Android 15, One UI.

| Signal | Observed |
|---|---|
| `TYPE_HINGE_ANGLE` present | yes |
| `FoldingFeature` reported | yes |
| Hinge convention | 0 closed → 180 flat (no correction needed) |
| Inner window | 360 × 880 dp |
| Cover window | 427.3 × 411.3 dp |
| Fold orientation | horizontal (tabletop/Flex Mode) |
| `isSeparating` when half-opened | true |
| Displays enumerated | 1 — both panels are the same logical display |

**Angle resolution: under investigation.** Three readings taken across the
device's range came back as exactly `0.0`, `90.0` and `180.0`, and the device
owner reports that slowly folding produces no intermediate values. That is
consistent with a sensor reporting at detents rather than sweeping, but the
diagnostic that would confirm it was itself broken at the time (see below), so
this is not yet established.

Run the report tool and read `hingeDistinctValues` and `hingeContinuous` to
settle it. A sweeping sensor passes a few dozen distinct values in a single
slow fold; a detent-reporting one stays in single figures no matter how slowly
the device is moved.

**If it is confirmed as detent-reporting, that is a hardware property, not a
bug** — and it matters, because it means continuous angle-driven effects
cannot be built on this device. Posture-driven layout is unaffected.

### Why the first measurement was wrong

`hingeEventCount` read `0` in every report while the angle was clearly
non-null, which is impossible: both are written in the same sensor callback.
The counter was being read from the capability snapshot, which is cached on
first call — so it was always the value from before any sensor event had
fired. Diagnostics are now a live call rather than a cached getter.

Worth stating plainly: a diagnostic that cannot be wrong is worth more than a
diagnostic that is usually right. This one was reporting a constant.

---

## Contributing an entry

```bash
flutter run -t tool/report_device.dart
```

Fold slowly through the whole range with the report open, then paste the
output into an issue. Useful extras: whether the app was launched on the cover
screen or the inner one, and what happens to posture when you open the device
while the app is running.
