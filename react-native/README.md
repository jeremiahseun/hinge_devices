# hinge_devices — React Native

A unified posture, hinge and display model for foldable devices.

Posture-first, capability-driven, and safe to add to any app — on a device
that doesn't fold, this package reports a rigid device and does nothing else.

> The same name and the same model ship to **npm** for React Native and
> **pub.dev** for Flutter. Both implementations run the conformance vectors in
> [`spec/posture_vectors.json`](../spec/posture_vectors.json), so `tabletop`
> means the same thing on both.

## Install

```sh
npm install hinge_devices
cd ios && pod install   # no-op: there is no iOS native module yet
```

**New Architecture only** (React Native 0.76+). The legacy bridge would double
the native surface and the testing matrix for a shrinking audience.

## Layout by posture

```tsx
import { useCoarsePosture, CoarsePosture } from 'hinge_devices';

function App() {
  const posture = useCoarsePosture();

  switch (posture) {
    case CoarsePosture.Closed:
      return <CompactLayout />;
    case CoarsePosture.HalfOpen:
      return <TabletopLayout />;
    case CoarsePosture.Open:
      return <FullLayout />;
  }
}
```

### Do not switch on `FoldPosture` directly

`FoldPosture` has seven values and a hierarchy. Matching one exactly is the
easiest way to break your app:

```tsx
// WRONG — silently drops flipClosed, so a shut Flip renders its opened layout
if (posture === FoldPosture.Closed) return <CompactLayout />;
return <FullLayout />;
```

A Galaxy Z Flip on its cover screen reports `flipClosed`, not `closed`. Use
`useCoarsePosture()`, or the `isClosed()` / `isHalfOpened()` helpers. When you
need the fine-grained value, match it *before* falling through:

```tsx
const { posture } = useFoldableDevice();

if (posture === FoldPosture.Tabletop) return <TabletopLayout />;
if (posture === FoldPosture.Book) return <BookLayout />;

switch (coarsePosture(posture)) { /* ... */ }
```

## Branch on capabilities, never on brand

```tsx
const capabilities = useFoldableCapabilities();

if (capabilities?.hingeAngleSensor) { /* offer an angle-driven effect */ }
if (capabilities?.outerDisplay)     { /* offer a cover-screen mode */ }

// Capabilities this package version has no field for are still readable:
if (capability(capabilities, 'someFutureCapability')) { /* ... */ }
```

## Hinge angle is for effects, not layout

```tsx
import { useHingeAngle } from 'hinge_devices';

const angle = useHingeAngle({ enabled: true, throttleMs: 16 });
```

Angle updates are **opt-in** and reference counted, so two components can each
ask for them and the first to unmount will not cut the sensor out from under
the second.

### Check the resolution before you build an angle effect

Nothing in Android's API says whether a hinge sensor sweeps through
intermediate values or only fires at fixed positions, and no vendor documents
it. **It varies by device, and it decides whether a continuous effect is
buildable at all.**

A Galaxy Z Flip 5 reports exactly three values — `0`, `90`, `180` — however
slowly you fold it.

```tsx
const { hinge } = useFoldableDevice();

if (supportsContinuousEffects(hinge)) {
  return <AngleDrivenEffect />;
}
return <PostureDrivenLayout />;   // meaningful on every foldable
```

`hinge.resolution` is `continuous`, `detents` or `unknown`, sourced from a
quirks table measured on real hardware. **`unknown` is not optimistic** —
assuming a smooth sweep and being wrong produces an effect that visibly snaps.
See [`doc/devices.md`](../doc/devices.md).

## Develop without a foldable

```tsx
import { setTestPosture, resetTestDevice, FoldPosture } from 'hinge_devices/src/testing';

setTestPosture(FoldPosture.Tabletop);   // every posture, one call away
resetTestDevice();                      // back to live
```

The same override path works from a debug menu in your own app, so what a test
exercises is what you can exercise by hand.

## Platform support

| Platform | Posture | Angle | Notes |
|---|---|---|---|
| Android 11+ | ✅ | ✅ | `FoldingFeature` + `TYPE_HINGE_ANGLE` |
| Android 7–10 | ✅ | ❌ | folding feature only |
| iOS | — | — | reports rigid; iPhone Duo support is next |

There is no iOS native module yet, so `TurboModuleRegistry.get` returns `null`
and the package reports a rigid device. That is deliberate: adding it to a
cross-platform app today is safe.

## Design notes

- **The platform reports facts; TypeScript derives meaning.** Native code
  sends a folding feature, a sensor reading, window metrics. Posture
  derivation, normalisation and deduplication happen in TS, so the rules are
  identical to the Dart implementation and testable without a device.
- **The Android hardware code is shared with the Flutter package.** The hinge
  sensor, window observer and display source live in `shared/android/` and are
  vendored into both; CI fails if the copies drift. A bug found on real
  hardware is fixed once.
- **A closed angle beats the folding feature; everything else is the
  reverse.** A Flip on its cover screen still reports a feature, so a fresh
  closed angle wins.
- **A missing signal is `null`, never a default.** `0` means fully closed,
  which is a very different claim from "we don't know".

## Versioning

Major and minor are shared with the Dart package, so one version number
describes one API on both frameworks; patch is independent. See
[VERSIONING.md](../VERSIONING.md).

```json
"hinge_devices": "~0.3.0"
```

## License

BSD-3-Clause.
