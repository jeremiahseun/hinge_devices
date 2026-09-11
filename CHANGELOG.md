## 0.2.0

Fixes two bugs found on a physical Galaxy Z Flip, plus the v0.2 milestone.

**Fixed**

- Posture stayed `flipClosed` after opening a Flip. A folding feature is only
  ever reported by an open device, so its presence now outranks a low hinge
  angle. Previously a stale sensor reading — the activity is recreated during
  the fold transition — kept the app on its closed layout indefinitely.
- The hinge sensor no longer holds a reading across an unregister. A stale `0`
  is indistinguishable from a device that is genuinely shut.
- The window-layout observer, not the sensor, is torn down on a config change.
  Unfolding *is* a config change, so the sensor now keeps delivering through
  exactly the moment posture is changing.
- Hinge angle only updated when the layout changed. Angle requests are now
  reference counted, so one `HingeAngleBuilder` disposing no longer turns the
  sensor off for every other one.
- The sensor runs at `SENSOR_DELAY_GAME` while angle updates are enabled and
  `SENSOR_DELAY_NORMAL` otherwise, instead of `SENSOR_DELAY_UI` always.
  Enabling angle updates raises the rate rather than turning the sensor on.

**Added**

- Cover and outer display detection via `DisplayManager`, populating
  `capabilities.outerDisplay` and `display.active`
- `package:foldable_runtime/testing.dart` — `FoldableTestPlatform`,
  `installFoldableTestPlatform`, `pumpFoldable`, `pumpFoldableState`,
  `forEachPosture`
- `FoldableDevice.diagnostics` for device reports
- `doc/continuity.md` and `tool/check_manifest.dart`, an app-continuity lint

**Changed**

- `PostureResolver.resolve` no longer returns a closed posture when a folding
  feature is present. This is a behaviour change; it is also the bug fix above.

## 0.1.0

Initial release — Flutter, Android only.

- Framework-independent core model: `FoldPosture`, `Hinge`, `DisplayInfo`,
  `FoldableCapabilities`, `FoldableState`
- Posture hierarchy: `tabletop` and `book` refine `halfOpened`; `flipClosed`
  refines `closed`
- Posture derived from Jetpack WindowManager's `FoldingFeature`, with
  `Sensor.TYPE_HINGE_ANGLE` used for closed detection and as a fallback
- Data-driven hinge normalisation with a runtime-extensible quirks table
- Configurable posture thresholds — no hard-coded angle assumptions
- Capability discovery with forward-compatible raw reads
- `FoldableBuilder`, `Foldable.of(context)`, `postureStream`, `stateStream`
- Opt-in `hingeAngleStream` and `HingeAngleBuilder`, in a separate `effects`
  import
- `debugOverride` posture simulation, plus an example app with a simulator panel
- `tool/report_device.dart` for contributing device quirks
- No-op implementation on every non-Android platform, so the package is safe to
  add to any multi-platform app
