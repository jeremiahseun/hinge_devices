# hinge_devices

A unified posture, hinge and display model for foldable devices — the same
model, the same name, and the same version on **Flutter** and **React Native**.

[![CI](https://github.com/jeremiahseun/hinge_devices/actions/workflows/ci.yml/badge.svg)](https://github.com/jeremiahseun/hinge_devices/actions/workflows/ci.yml)
[![pub package](https://img.shields.io/pub/v/hinge_devices.svg)](https://pub.dev/packages/hinge_devices)
[![pub points](https://img.shields.io/pub/points/hinge_devices)](https://pub.dev/packages/hinge_devices/score)
[![License: BSD-3-Clause](https://img.shields.io/badge/license-BSD--3--Clause-blue.svg)](LICENSE)

```dart
// Flutter
switch (state.posture.coarse) {
  CoarsePosture.closed   => CompactLayout(),
  CoarsePosture.halfOpen => TabletopLayout(),
  CoarsePosture.open     => FullLayout(),
}
```

```tsx
// React Native — same names, same semantics
switch (useCoarsePosture()) {
  case CoarsePosture.Closed:   return <CompactLayout />;
  case CoarsePosture.HalfOpen: return <TabletopLayout />;
  case CoarsePosture.Open:     return <FullLayout />;
}
```

## Repository layout

| Folder | What it is | Ships to |
|---|---|---|
| [`core-android/`](core-android/) | The Android hardware code — hinge sensor, window-layout observer, display source. **Source of truth.** | vendored into both |
| [`flutter/`](flutter/) | The Flutter plugin | [pub.dev](https://pub.dev/packages/hinge_devices) |
| [`react-native/`](react-native/) | The React Native module | [npm](https://www.npmjs.com/package/hinge_devices) |
| [`spec/`](spec/) | The cross-language contract: conformance vectors and the shared version | — |
| [`doc/`](doc/) | Measured device behaviour and app-continuity guidance | — |
| [`tool/`](tool/) | Repo tooling: version check, shared-code sync | — |

## Why the folders exist

The two packages are **not ports of each other**. They are two implementations
of one specification, and the specification is executable:

- **[`spec/posture_vectors.json`](spec/posture_vectors.json)** holds the
  conformance vectors. Both implementations run them in CI. A posture rule
  changed in one language and not the other fails the build, rather than
  silently shipping two products that disagree about what `tabletop` means.
- **[`core-android/`](core-android/)** holds the Android hardware code once.
  `dart run tool/sync_shared.dart` vendors it into both packages, and
  `--check` fails CI on drift. Every bug found on real hardware is fixed once.
- **[`spec/version.json`](spec/version.json)** keeps major and minor in step
  across pub.dev and npm; patch is per package. See
  [VERSIONING.md](VERSIONING.md).

Vendoring rather than a shared Maven artifact because a published package has
to be self-contained: the pub.dev archive ships only `flutter/android/`, the
npm tarball only `react-native/android/`.

## Getting started

- **Flutter** → [`flutter/README.md`](flutter/README.md)
- **React Native** → [`react-native/README.md`](react-native/README.md)

## Status

**Android only, on both frameworks.** Validated on a physical Samsung Galaxy Z
Flip 5 across five rounds of on-device testing; every bug that testing found is
fixed and covered by a regression test.

**iOS ships in 0.4, with the iPhone Duo** — Apple's Hinge API, device poses and
Scene Accessories. Neither package declares iOS support until that is real: the
platform badge is how you will find out it arrived. Both are safe to add to a
multi-platform app today, where they report a rigid device and do nothing.

See [PRD.md](PRD.md) for the roadmap and an honest critique of it, and
[doc/devices.md](doc/devices.md) for what has actually been measured on real
hardware — including the finding that a Z Flip 5's hinge sensor reports exactly
three angles, so continuous angle-driven effects are not buildable there.

## Contributing

The most valuable contribution is **a device report, not code**. See
[CONTRIBUTING.md](CONTRIBUTING.md).

## License

BSD-3-Clause.
