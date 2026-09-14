## 0.3.0

First public release, as `hinge_devices`.

The same name ships to pub.dev and npm, so `dart pub add hinge_devices` and
`npm i hinge_devices` are the same product rather than two.

Flutter + Android, validated on a physical Samsung Galaxy Z Flip 5 across five
rounds of on-device testing. Every bug that testing found is fixed and covered
by a regression test.

**Added**

- `HingeResolution` and `Hinge.supportsContinuousEffects`. Nothing in Android's
  API says whether `TYPE_HINGE_ANGLE` sweeps through intermediate values or
  only fires at fixed positions, and no vendor documents it — but it decides
  whether a continuous angle-driven effect is buildable at all. Measured on a
  Z Flip 5: exactly three values, `[0, 90, 180]`, however slowly the device is
  folded. That is now a shipped quirk, so every app on that hardware gets the
  answer without discovering it the hard way.
- `spec/version.json`, `tool/check_versions.dart` and `VERSIONING.md`. Major
  and minor are shared across the Dart and npm packages so one version number
  describes one API on every framework; patch is per package. CI fails on
  drift.
- Continuous integration: analyze, format, test, version check, publish
  dry-run and a pana score floor on every push.

See `doc/devices.md` for measured per-device behaviour, and `PRD.md` for the
roadmap and its critique.

### Earlier development

## 0.2.2

**Fixed**

- `diagnostics` reported a constant. Live counters were being read from the
  capability snapshot, which is cached on first call, so `hingeEventCount` was
  always the value from before any sensor event had fired — it read `0`
  forever, including on a device that was clearly delivering angles.
  Diagnostics are now a live platform call: `FoldableDevice.diagnostics()`.
- A Z Flip 5 running on its Flex Window reported `outerDisplay: false` and
  `activeDisplay: unknown`, so it resolved to `closed` rather than
  `flipClosed`. Both panels are the same logical display on that hardware, so
  no amount of display enumeration can see the cover screen. Replaced with a
  deduction: a device that is shut and still drawing must be drawing on an
  outer panel. Correct on the first launch, and it uses the same configurable
  threshold that decides `closed`, so the two can never disagree.

**Added**

- Live hinge statistics: `hingeEventCount`, `hingeDistinctValues`,
  `hingeValuesSeen`, `hingeMin`, `hingeMax`, `hingeContinuous`. These answer a
  question no vendor documents — whether a given hinge sensor sweeps
  continuously or only reports at detents, which decides whether angle-driven
  effects are viable on that device.
- `FoldableCapabilities.copyWith`, keeping typed and raw reads in agreement.
- `doc/devices.md`, recording measured behaviour per device.
- The report tool polls diagnostics live instead of printing a startup
  snapshot.

**Breaking**

- `FoldableDevice.diagnostics` is now a method, not a getter. It could not be
  correct as a getter.

## 0.2.1

Fixes two regressions found on a physical Galaxy Z Flip, plus the API flaw that
let one of them happen.

**Fixed**

- A Flip running on its cover screen reported an open posture. 0.2.0 let a
  folding feature outrank a closed hinge angle, but a Flip on its Flex Window
  still reports a feature. A fresh closed angle wins again; the stale-reading
  hazard that change was guarding against is handled at the sensor instead,
  where 0.2.0 already fixed it.
- Hinge angle stopped streaming entirely. `emitState` was reading window and
  display APIs from the hinge sensor's callback thread, which threw inside
  `onSensorChanged` and killed every angle update, while main-thread
  window-layout callbacks kept working and masked it. State is now always
  built on the main thread, and a failed read drops one update instead of the
  stream.
- Cover-screen detection reflected onto `Display.getType()`, which is hidden
  API and blocked from Android 9 onward — it failed silently and reported
  every display as external. Replaced with public signals only:
  `FLAG_PRESENTATION`/`FLAG_PRIVATE` plus a window-size comparison. It reports
  `unknown` rather than guessing, and it never feeds posture.

**Added**

- `CoarsePosture` and `FoldPosture.coarse`, collapsing seven postures to the
  three apps branch on. Switching on `FoldPosture` directly and matching
  `FoldPosture.closed` exactly silently drops `flipClosed` — which is how a
  shut Flip ended up rendering its opened layout. `CoarsePosture` is
  exhaustive, so the analyzer catches it.
- An always-visible diagnostics strip in the example app: posture, live angle,
  angle bar, active display and capabilities.

**Changed**

- The display lookup is cached against window size, so it is off the hot path
  when an angle-driven effect is running.
- `android/.gradle` and `android/local.properties` are no longer tracked.

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
- `package:hinge_devices/testing.dart` — `FoldableTestPlatform`,
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
