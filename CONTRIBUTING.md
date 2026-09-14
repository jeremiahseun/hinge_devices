# Contributing

The most valuable contribution to this package is **a device report**. Not
code — data.

## Report a device

We will never own every foldable ever made, and every one of them behaves
slightly differently in ways no vendor documents. Four of the bugs fixed so
far were found by running the app on one real Galaxy Z Flip.

```bash
git clone https://github.com/jeremiahseun/hinge_devices
cd hinge_devices/flutter/example
flutter run -t tool/report_device.dart
```

Fold the device slowly through its whole range with the report open, then open
an issue with the output. The lines that matter most:

- `hingeDistinctValues` and `hingeContinuous` — whether the sensor sweeps or
  only reports at fixed positions. This decides whether angle-driven effects
  are buildable on that device, and it is the single least-documented fact
  about foldable hardware.
- `raw angle` at closed, halfway and flat — this is how we detect a device
  that inverts the scale or sweeps to 360.
- `active display` when the app is launched on a cover screen.

Add what posture the device *should* have been in, and anything that looked
wrong. See `doc/devices.md` for the entries we have.

## Code

The repository holds three things: the shared Android code, and one package
per framework.

| Folder | What it is |
|---|---|
| `core-android/` | Android hardware code. **Edit here**, never in a package. |
| `flutter/` | The pub.dev package |
| `react-native/` | The npm package |
| `spec/` | Conformance vectors and the shared version |

```bash
# Flutter
cd flutter
flutter pub get && flutter test && flutter analyze
dart format lib bin test example/lib example/tool

# React Native
cd react-native
npm ci && npm run typecheck && npm test

# Cross-package contracts, from the repo root
dart run tool/check_versions.dart
dart run tool/sync_shared.dart --check
```

After editing anything in `core-android/`, run `dart run tool/sync_shared.dart`
to vendor it into both packages. CI fails if you forget.

CI runs all of the above plus a publish dry run, a pana score floor of
160/160, an npm pack check, and an Android build. Everything it checks is
something a user of this package would notice, so please run them locally
first.

### House rules

- **A posture rule change goes in `spec/posture_vectors.json` first.** Both
  implementations run those vectors, so a rule changed in one language and not
  the other fails the build instead of silently shipping two products that
  disagree.
- **A bug fix comes with a regression test.** Every bug found on real hardware
  has one, named for the symptom rather than the function.
- **The platform reports facts; Dart derives meaning.** Native code sends a
  folding feature, a sensor reading, window metrics. Posture derivation,
  normalisation and deduplication happen in Dart so the rules are identical on
  every platform and testable without hardware.
- **A heuristic must never decide posture.** Cover-screen detection is
  inference and can be wrong; it informs `display.active` and nothing else.
- **A missing signal is `null`, never a default.** `0` means fully closed,
  which is a very different claim from "we don't know".
- **Never register a sensor you are not using.** Battery complaints are how
  packages like this one get removed.

### Versioning

Major and minor are shared between the Dart and npm packages; patch is
independent. Edit `spec/version.json`, never a manifest directly — see
[VERSIONING.md](VERSIONING.md). CI fails on drift.

## Scope

This package answers "what is this device doing, physically, and what can it
do". It is deliberately not a layout library: Flutter already ships
`MediaQuery.displayFeatures` and `TwoPane`, and competing with the SDK is a
losing position. Proposals that add adaptive-layout widgets will probably be
declined; proposals that add signals, capabilities or device knowledge are
very welcome.
