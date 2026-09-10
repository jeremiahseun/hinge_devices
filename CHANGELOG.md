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
