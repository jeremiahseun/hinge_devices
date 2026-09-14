# hinge_devices — Flutter

[![pub package](https://img.shields.io/pub/v/hinge_devices.svg)](https://pub.dev/packages/hinge_devices)
[![pub points](https://img.shields.io/pub/points/hinge_devices)](https://pub.dev/packages/hinge_devices/score)
[![CI](https://github.com/jeremiahseun/hinge_devices/actions/workflows/ci.yml/badge.svg)](https://github.com/jeremiahseun/hinge_devices/actions/workflows/ci.yml)
[![License: BSD-3-Clause](https://img.shields.io/badge/license-BSD--3--Clause-blue.svg)](LICENSE)

A unified posture, hinge and display model for foldable devices.

Posture-first, capability-driven, and safe to add to any app — on a device that
doesn't fold, this package reports a rigid device and does nothing else.

> **Status: 0.3 — Flutter and React Native, Android.** Validated on a physical
> Galaxy Z Flip 5 across five rounds of on-device testing. iOS (iPhone Duo) is
> next. See [PRD.md](../PRD.md) for the roadmap and its critique.
>
> **React Native users:** [`../react-native/`](../react-native/) — same name on npm,
> same model, same version.

## Why this and not `MediaQuery.displayFeatures`

Flutter already tells you *where the fold is*. This tells you *what the device
is doing* and *what it can do*:

| | `displayFeatures` | `hinge_devices` |
|---|---|---|
| Fold bounds | ✅ | ✅ |
| Named posture (tabletop, book, closed) | ❌ | ✅ |
| Hinge angle | ❌ | ✅ |
| Capability discovery | ❌ | ✅ |
| Closed / cover-screen detection | ❌ | ✅ |
| Simulate postures without hardware | ❌ | ✅ |

Use both. `displayFeatures` for avoiding the hinge, this for deciding the layout.

## Install

```yaml
dependencies:
  hinge_devices: ^0.1.0
```

## Layout by posture

```dart
FoldableBuilder(
  builder: (context, state) => switch (state.posture.coarse) {
    CoarsePosture.closed   => CompactLayout(),
    CoarsePosture.halfOpen => TabletopLayout(),
    CoarsePosture.open     => FullLayout(),
  },
);
```

### Do not switch on `FoldPosture` directly

`FoldPosture` has seven values and a hierarchy. Matching one of them exactly is
the easiest way to break your app:

```dart
// WRONG — silently drops flipClosed, so a shut Flip renders its opened layout
switch (state.posture) {
  FoldPosture.closed => CompactLayout(),
  _ => FullLayout(),
}
```

`CoarsePosture` collapses the seven to the three states apps actually branch
on, and it is exhaustive — so a posture added in a later release becomes an
analyzer error in your app rather than a layout that quietly stops appearing.
When you do need the fine-grained value, match it *before* falling through:

```dart
if (state.posture == FoldPosture.tabletop) return TabletopLayout();
if (state.posture == FoldPosture.book) return BookLayout();

return switch (state.posture.coarse) {
  CoarsePosture.closed   => CompactLayout(),
  CoarsePosture.halfOpen => HalfOpenLayout(),
  CoarsePosture.open     => FullLayout(),
};
```

`posture.isHalfOpened` and `posture.isClosed` are the other safe reads.

Or `MediaQuery`-style, once at the root:

```dart
Foldable(child: MyApp());

// anywhere below
final posture = Foldable.of(context).posture;
```

`tabletop` and `book` are refinements of `halfOpened`; `flipClosed` is a
refinement of `closed`.

## Branch on capabilities, never on brand

```dart
final caps = await FoldableDevice.instance.capabilities;

if (caps.hingeAngleSensor) { /* enable an angle-driven effect */ }
if (caps.outerDisplay)     { /* offer a cover-screen mode */ }

// Capabilities this package version has no field for are still readable:
if (caps['someFutureCapability']) { ... }
```

## Hinge angle is for effects, not layout

Angle lives behind a separate import on purpose. Driving layout from a
continuous angle thrashes at the threshold boundaries — that is what posture is
for. Both Android's and Apple's own guidance says the same thing.

```dart
import 'package:hinge_devices/effects.dart';

HingeAngleBuilder(
  autoEnable: true,
  builder: (context, angle) => Opacity(
    opacity: (angle / 180).clamp(0.0, 1.0),
    child: child,
  ),
);
```

Angle updates are **opt-in** (`enableAngleUpdates()`, or `autoEnable: true`) and
the sensor is unregistered when nothing is listening. It is the only part of
this package that can measurably cost battery.

### Check the resolution before you build an angle effect

Nothing in Android's API says whether a hinge sensor sweeps through
intermediate values or only fires at fixed positions, and no vendor documents
it. **It varies by device, and it decides whether a continuous effect is
buildable at all.**

A Galaxy Z Flip 5 reports exactly three values — `0`, `90`, `180` — however
slowly you fold it. An effect that maps hinge angle onto a slider has three
states there, not a smooth range.

```dart
final hinge = Foldable.of(context).hinge;

if (hinge.supportsContinuousEffects) {
  return HingeAngleBuilder(autoEnable: true, builder: ...);
}
// Fall back to posture: it is meaningful on every foldable.
return FoldableBuilder(builder: ...);
```

`hinge.resolution` is `continuous`, `detents` or `unknown`, sourced from a
quirks table measured on real hardware. **`unknown` is not optimistic** —
assuming a smooth sweep and being wrong produces an effect that visibly snaps,
which is worse than not offering it. See [doc/devices.md](../doc/devices.md) for
what has been measured, and please add your device.

## Develop without a foldable

```dart
// Wire this to a debug menu — every posture, one tap away, on any emulator.
FoldableDevice.instance.debugOverride(
  const FoldableState(posture: FoldPosture.tabletop),
);
FoldableDevice.instance.debugOverride(null); // back to live
```

On an Android foldable AVD you can also drive the real sensor:

```bash
adb emu sensor set hinge-angle0 90
```

The example app ships a working simulator panel. Run it:

```bash
cd example && flutter run
```

## Test every posture

```dart
import 'package:hinge_devices/testing.dart';

testWidgets('adapts to tabletop', (tester) async {
  final device = installFoldableTestPlatform();
  addTearDown(FoldableDevice.resetForTesting);

  await tester.pumpWidget(const MyApp());
  await pumpFoldable(tester, device, FoldPosture.tabletop);

  expect(find.byType(TabletopLayout), findsOneWidget);
});
```

`forEachPosture` runs a body across the whole matrix, so one test covers every
posture your app can be in.

## App continuity

Keeping state when the device opens is a manifest concern, not an API — there
is no continuity call to make. Check yours:

```bash
dart run hinge_devices:check_manifest
```

See [doc/continuity.md](../doc/continuity.md).

## Device quirks

Vendors disagree about hinge convention: most report `0` closed to `180` flat,
some sweep to `360`, at least one inverts the scale. Corrections live in data,
not code:

```dart
FoldableQuirks.register(
  'weirdcorp/wc-1',
  const HingeQuirk(range: HingeAngleRange.zeroTo360),
);
```

Own a foldable we haven't got an entry for? Run `example/tool/report_device.dart` and paste the output into an issue.

## Platform support

| Platform | Posture | Angle | Notes |
|---|---|---|---|
| Android 11+ | ✅ | ✅ | `FoldingFeature` + `TYPE_HINGE_ANGLE`; cover display detected |
| Android 7–10 | ✅ | ❌ | folding feature only |
| iOS | — | — | reports rigid; iPhone Duo support in v0.3 |
| Web, desktop | — | — | reports rigid; safe to include |

## One model, two frameworks

`hinge_devices` ships to pub.dev for Flutter and npm for React Native. They
are not ports of each other — they are two implementations of one
specification, and the specification is executable:

- [`spec/posture_vectors.json`](../spec/posture_vectors.json) holds the
  conformance vectors. **Both implementations run them in CI.** A posture rule
  changed in one language and not the other fails the build, rather than
  silently shipping two products that disagree about what `tabletop` means.
- [`core-android/`](../core-android/) holds the Android hardware code — the
  hinge sensor, the window-layout observer, the display source. It is vendored
  into both packages by `dart run tool/sync_shared.dart`, and CI fails on
  drift. Every bug found on real hardware is fixed once, for both frameworks.
- [`spec/version.json`](../spec/version.json) keeps major and minor in step
  across both ecosystems.

## Design notes

- **The platform reports facts; Dart derives meaning.** Native code sends a
  folding feature and a sensor reading. Posture derivation, angle
  normalisation and deduplication all happen in Dart, so the rules are
  identical on every platform and testable without hardware.
- **A closed angle beats the folding feature; everything else is the reverse.**
  `closed` is the one posture no folding feature reports, and a Flip running on
  its cover screen can still report a feature — so a fresh closed angle wins.
  Everywhere else the folding feature decides, with angle as the fallback.
- **Staleness is fixed at the source, not in the resolver.** The hinge sensor
  clears its reading when unregistered and keeps running through the
  configuration change that unfolding triggers, so a stale reading arrives as
  `null` — and `null` never resolves to `closed`. That is what stops an opened
  Flip from sticking on its closed layout, without letting a folding feature
  overrule a device that is genuinely shut.
- **Heuristics never touch posture.** Cover-screen detection is a size
  comparison, because Android exposes no public API for it. It informs
  `display.active` and reports `unknown` when it cannot tell — it can never put
  a device on the wrong layout.
- **Posture events are deduplicated; angle events are not.** Emitting a posture
  sixty times a second because the angle wiggled is the classic performance
  mistake in this category.
- **A missing sensor is `null`, never `0`.** `0` means "fully closed", which is
  a very different claim from "we don't know".

## Versioning

The same name ships to pub.dev and npm. Major and minor are shared across both,
so one version number describes one API on both frameworks; patch is
independent. Pin a minor:

```yaml
hinge_devices: ^0.3.0
```

The package is pre-1.0 while iOS and React Native are unbuilt, and `0.x` minor
bumps may break API — they have, more than once, because real hardware keeps
teaching us things. See [VERSIONING.md](../VERSIONING.md).

## Contributing

The most valuable contribution is **a device report, not code**. Four of the
bugs fixed so far were found by running the example on one real Galaxy Z Flip.

```bash
cd example && flutter run -t tool/report_device.dart
```

See [CONTRIBUTING.md](../CONTRIBUTING.md).

## License

BSD-3-Clause.
