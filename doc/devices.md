# Observed device behaviour

Vendors document almost nothing about what their hinge sensors actually
report. This file records what we have measured on real hardware. Entries come
from `cd example && flutter run -t tool/report_device.dart`.

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

### Angle resolution: detents, confirmed

```
hingeDistinctValues: 3
hingeValuesSeen:     [0.0, 90.0, 180.0]
hingeContinuous:     false
```

Measured after folding the device slowly through its full range repeatedly.
**This sensor does not sweep.** It reports three positions and nothing in
between, no matter how slowly the device is moved.

This is a hardware property, not a bug, and it has a real consequence:
**continuous angle-driven effects cannot be built on this device.** An effect
that maps hinge angle onto a slider, a volume curve or a parallax has three
states here. Posture-driven layout is entirely unaffected — `flat`,
`tabletop`, `book` and `flipClosed` all work exactly as intended.

Shipped as a quirk, so every app on this hardware gets the answer without
having to discover it:

```dart
'samsung/sm-f731n': HingeQuirk(
  range: HingeAngleRange.zeroTo180,
  resolution: HingeResolution.detents,
  detentValues: [0, 90, 180],
),
```

Check `hinge.supportsContinuousEffects` before building an angle effect.

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
cd example && flutter run -t tool/report_device.dart
```

Fold slowly through the whole range with the report open, then paste the
output into an issue. Useful extras: whether the app was launched on the cover
screen or the inner one, and what happens to posture when you open the device
while the app is running.
