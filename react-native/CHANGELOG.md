## 0.3.0

First release. React Native, Android, New Architecture only.

Joins the Dart package at 0.3.0 rather than starting at 0.1.0: major and minor
are shared across both ecosystems so one version number describes one API on
both frameworks. See [VERSIONING.md](../VERSIONING.md).

**Added**

- `useFoldableDevice`, `useFoldPosture`, `useCoarsePosture`,
  `useFoldableCapabilities`, `useHingeAngle`, `useFoldableDebugOverride`
- The full model: `FoldPosture` with its hierarchy, `CoarsePosture`, `Hinge`,
  `HingeResolution`, `DisplayInfo`, `FoldableCapabilities` with
  forward-compatible raw reads, and the shipped device quirks table
- `resolvePosture` and `hingeStatusFor`, verified against
  `spec/posture_vectors.json` — the same vectors the Dart package runs
- Android TurboModule over Jetpack WindowManager and `TYPE_HINGE_ANGLE`,
  sharing its hardware sources with the Flutter plugin via `shared/android/`
- Angle updates are opt-in and reference counted, so one component unmounting
  cannot cut the sensor out from under another
- `src/testing.ts` — `setTestPosture`, `stateFor`, `resetTestDevice`

**Notes**

- No iOS native module yet, so the package reports a rigid device there.
  Adding it to a cross-platform app today is safe.
- Requires React Native 0.76+. The legacy bridge is not supported.
