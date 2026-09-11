# foldable_runtime

A unified posture, hinge and display model for foldable devices.

Posture-first, capability-driven, and safe to add to any app — on a device that
doesn't fold, this package reports a rigid device and does nothing else.

> **Status: v0.2 — Flutter + Android**, verified on a physical Galaxy Z Flip.
> iOS (iPhone Duo) and React Native are on the roadmap. See [PRD.md](PRD.md)
> for the full plan and the honest critique of it.

## Why this and not `MediaQuery.displayFeatures`

Flutter already tells you *where the fold is*. This tells you *what the device
is doing* and *what it can do*:

| | `displayFeatures` | `foldable_runtime` |
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
  foldable_runtime: ^0.1.0
```

## Layout by posture

```dart
FoldableBuilder(
  builder: (context, state) => switch (state.posture) {
    FoldPosture.tabletop => TabletopLayout(),   // horizontal fold
    FoldPosture.book     => BookLayout(),       // vertical fold
    _ when state.posture.isClosed => CompactLayout(),
    _ => FullLayout(),
  },
);
```

Or `MediaQuery`-style, once at the root:

```dart
Foldable(child: MyApp());

// anywhere below
final posture = Foldable.of(context).posture;
```

`tabletop` and `book` are refinements of `halfOpened`, and `flipClosed` is a
refinement of `closed`. Use `posture.isHalfOpened` / `posture.isClosed` so your
code survives the next hardware generation adding a new refinement.

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
import 'package:foldable_runtime/effects.dart';

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
import 'package:foldable_runtime/testing.dart';

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
dart run tool/check_manifest.dart android/app/src/main/AndroidManifest.xml
```

See [doc/continuity.md](doc/continuity.md).

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

Own a foldable we haven't got an entry for? Run `flutter run -t
tool/report_device.dart` and paste the output into an issue.

## Platform support

| Platform | Posture | Angle | Notes |
|---|---|---|---|
| Android 11+ | ✅ | ✅ | `FoldingFeature` + `TYPE_HINGE_ANGLE`; cover display detected |
| Android 7–10 | ✅ | ❌ | folding feature only |
| iOS | — | — | reports rigid; iPhone Duo support in v0.3 |
| Web, desktop | — | — | reports rigid; safe to include |

## Design notes

- **The platform reports facts; Dart derives meaning.** Native code sends a
  folding feature and a sensor reading. Posture derivation, angle
  normalisation and deduplication all happen in Dart, so the rules are
  identical on every platform and testable without hardware.
- **Folding feature beats angle, always.** A shut device reports no folding
  feature, so one being present proves the device is open. Angle is consulted
  for `closed` only when there is no folding feature, and as a fallback when
  the device has none at all. Trusting a low angle over a live folding feature
  is how an opened Flip stays stuck on its closed layout.
- **Posture events are deduplicated; angle events are not.** Emitting a posture
  sixty times a second because the angle wiggled is the classic performance
  mistake in this category.
- **A missing sensor is `null`, never `0`.** `0` means "fully closed", which is
  a very different claim from "we don't know".

## License

BSD-3-Clause.
