# PRD — Foldable Device Runtime

**Working package name:** `foldable_runtime` (Dart) / `@foldable/runtime` (npm)
**Repo:** `jeremiahseun/hinge_devices`
**Owner:** Jeremiah Seun
**Status:** Draft v1 — pre-implementation
**Date:** 2026-09-10
**License target:** BSD-3-Clause (Flutter ecosystem norm; MIT for the RN package)

---

## 0. TL;DR

A framework-independent posture model for foldable devices, exposed identically to Flutter and React Native, backed by Android (`Sensor.TYPE_HINGE_ANGLE`, Jetpack WindowManager, WindowArea) and iOS 27 (Hinge API, scene arrangement/region, Scene Accessories).

The product is **not** a hinge-angle wrapper. Hinge angle is a 40-line platform channel and three packages already do it. The product is:

1. A **capability model** so app code never branches on device brand or OS version.
2. A **posture model** derived from display features first, angle second — matching what both platform vendors actually recommend.
3. **Parity** across Flutter and React Native, Android and iOS, from one core spec.
4. A **test harness** that lets developers simulate every posture without owning a $2,000 device.

That fourth one is the actual wedge. Everything else is commoditised within six months.

---

## 1. Why now

Three things converged inside 12 months, and the window is roughly one quarter wide.

| Platform | Capability | Status |
|---|---|---|
| Android | `Sensor.TYPE_HINGE_ANGLE` | Stable since API 30 (2020) |
| Android | Jetpack WindowManager `FoldingFeature` | Stable |
| Android | `WindowAreaController` — rear display / dual concurrent | Stable |
| Samsung | Flex Mode, Flex Window (cover screen) | Mature, One UI |
| Apple | iPhone Duo — 5.4" outer, 7.6" inner | Announced 2026-09-09, preorder 10-16, ships 10-23 |
| Apple | Hinge API — `onHingeChange` / `UIHingeInteraction` | iOS 27.x |
| Apple | Scene Accessories, `CameraCaptureAccessory` | iOS 27.x |

**The window:** between 2026-09-09 and roughly 2026-12-31, every Flutter and RN developer with a Duo in their pocket will search "flutter foldable" exactly once and adopt whatever they find on the first page. There is currently no credible cross-platform answer. After Q1 2027, either Google/Flutter ships first-party support or an incumbent package adds Duo and the slot closes.

**Honest read on market size:** foldables are ~1.5–2% of global smartphone shipments. This is not a large-TAM package. Its value is positional (see §12), not volumetric.

---

## 2. Corrections to the original concept

Four things in the source brief are wrong or will cost us if carried into v0.1.

### 2.1 `FoldingFeature` does not expose hinge angle
The brief conflates them. Jetpack WindowManager's `FoldingFeature` gives `state` (`FLAT` | `HALF_OPENED`), `orientation`, `occlusionType`, and `bounds` — **no angle**. Angle comes only from `Sensor.TYPE_HINGE_ANGLE`, a separate hardware sensor with separate availability. Two independent sources, two independent capability flags, and they can disagree. The architecture must fuse them, not treat one as the other.

### 2.2 Flutter already ships part of v0.1
`MediaQuery.of(context).displayFeatures` is in the Flutter framework today and gives hinge/cutout bounds and state. So does the `TwoPane` widget. Positioning this package as "Flutter foldable support" against the SDK itself is a losing pitch. Correct positioning: **displayFeatures tells you where the fold is; this tells you what the device is doing and what it can do** — plus angle, active display, capabilities, and RN parity.

### 2.3 Apple explicitly tells you not to do what §11 of the brief proposes
Apple's Tech Talk is unambiguous: use `arrangement` / `region` / size classes / scene geometry for **layout**; use hinge data for **interactions and effects** (parallax, cover animations, shutters). The brief's instinct — "posture is the primary API, angle is secondary" — is directionally right but the reason is stronger than stated: driving layout off a continuous angle produces jank, thrash, and rejected-feeling apps. Our API should make the correct thing easy and the incorrect thing visibly discouraged.

### 2.4 "Samsung app continuity" is not an API
Continuity between cover and main display is configuration — `android:resizeableActivity`, `configChanges`, `minAspectRatio`, and manifest metadata — not a runtime call. Shipping it as a "v0.2 feature" oversells it. It becomes **documentation plus a manifest lint**, which is genuinely useful and takes a day, not a milestone.

### 2.5 Rear display mode will break Flutter if we ship it naively
`WindowAreaController.transferActivityToWindowArea` moves the Activity. On Flutter that risks engine teardown, state loss, and surface re-creation. This is not a v0.1 feature. It is a v0.4 feature with an explicit stateful-restoration story, or it is a footgun that generates our worst GitHub issues.

---

## 3. Goals / Non-goals

### Goals
- G1. One posture vocabulary, identical semantics on Flutter and RN, Android and iOS.
- G2. Capability discovery so no app ever branches on brand, model, or SDK level.
- G3. Angle as a first-class *effects* input, with correct lifecycle and battery behaviour.
- G4. Zero-crash, zero-throw on non-foldables — the package must be safe to add to any app.
- G5. Simulatable: every posture reproducible in CI and on an emulator/simulator.

### Non-goals (v1)
- N1. Layout widgets. No `TwoPane` clone. Flutter has one; we do not compete with the SDK.
- N2. Rear display transfer / dual-concurrent display (deferred to v0.4, gated).
- N3. Windows/desktop/dual-screen laptops.
- N4. Tablets and large-screen adaptivity in general. Scope is *physical posture*, not responsive design.
- N5. Any device-brand SDK dependency (no Samsung SDK jar, no OEM binaries).

---

## 4. Users and jobs

| Persona | Job to be done | Success signal |
|---|---|---|
| **Solo Flutter dev with a Z Flip** | "Make my app not look stupid in Flex Mode" | 15 min from `pub add` to working tabletop layout |
| **RN team shipping a camera app** | "Put controls on the cover screen" | Scene Accessory works without writing Swift |
| **Media/game dev** | "Drive an effect off the hinge" | 60fps angle stream, no dropped frames |
| **Enterprise team** | "Don't crash on 98% of devices that aren't foldable" | Capability checks, no platform exceptions |
| **Us** | Credibility, inbound, positioning | See §12 |

---

## 5. Core model (framework-independent)

The core is a spec + a reference implementation, shared verbatim by both bindings. Written once, in `spec/`, as a machine-readable JSON schema plus prose, so Dart and TS types are generated, not hand-written twice.

### 5.1 Posture

```
enum FoldPosture {
  unknown,        // no signal yet, or unsupported device mid-query
  flat,           // fully open, single continuous surface (Duo: fullyOpen)
  halfOpened,     // hinge between thresholds, orientation unspecified
  tabletop,       // halfOpened + horizontal fold (Flex Mode / laptop)
  book,           // halfOpened + vertical fold
  closed,         // folded shut; outer/cover display is active if any
  flipClosed,     // closed, but a usable cover display exists (Flip / Duo)
}
```

`tabletop` and `book` are **refinements** of `halfOpened`, not siblings. API must expose both levels so a developer can write `if (posture.isHalfOpened)` without enumerating refinements. This is where the existing RN package gets it wrong — it returns three flat booleans with no hierarchy.

### 5.2 Hinge

```
class Hinge {
  double? angle;              // null when no sensor. Normalised, see 5.2.1
  HingeAngleRange range;      // .zeroTo180 | .zeroTo360 | .unknown
  double? rawAngle;           // untouched platform value, for debugging
  HingeStatus status;         // closed | partiallyOpen | fullyOpen | unknown
  Axis? orientation;          // horizontal | vertical | null
}
```

**5.2.1 Normalisation.** Android devices disagree on convention: most report 0–180 (0 = closed), some report 0–360, and at least one OEM inverts it. `angle` is always normalised to **0 = fully closed, 180 = fully flat**, with `rawAngle` preserved. Devices needing correction live in a `quirks.json` keyed by `Build.MANUFACTURER`/`MODEL`, shipped as data and overridable at runtime. Do not compile quirks into code — they will change faster than our release cadence.

**5.2.2 Thresholds are configurable, never hard-coded.** Default `closed < 15°`, `flat > 165°`, `halfOpened` between. Consumers can override. The brief was right about this and it is the single most important line in the spec.

### 5.3 Display

```
enum ActiveDisplay { inner, outer, cover, rear, unknown }

class DisplayInfo {
  ActiveDisplay active;
  List<DisplayFeature> features;   // hinge/cutout bounds, from WindowManager / region API
  Size logicalSize;
  bool isSeparating;               // does the feature split content into logical panes
}
```

### 5.4 Capabilities — the load-bearing part

```
class FoldableCapabilities {
  bool isFoldable;
  bool hingeAngleSensor;      // Android sensor present / iOS hinge non-null
  bool foldingFeature;        // WindowManager / arrangement+region available
  bool outerDisplay;          // a cover/outer screen exists
  bool sceneAccessory;        // can render to outer while inner is active (iOS 27+)
  bool rearDisplayTransfer;   // WindowAreaController rear mode (Android)
  bool dualConcurrent;        // both displays simultaneously
  int  specVersion;           // forward-compat: unknown caps are readable as raw map
}
```

`capabilities.raw` exposes an untyped `Map<String, bool>` alongside the typed struct so a v0.9 device capability is readable by a v0.5 app. Every foldable library that hard-codes its capability enum dies on the next hardware generation.

### 5.5 The unified event

```
class FoldableState {
  FoldPosture posture;
  Hinge hinge;
  DisplayInfo display;
  FoldableCapabilities capabilities;
  DateTime timestamp;
}
```

One stream of `FoldableState`, plus derived narrow streams for convenience. **Postures are deduplicated; angle is not.** Emitting a posture event 60×/second because the angle wiggled is the number one performance mistake in this category.

---

## 6. Public API

### 6.1 Flutter

```dart
// Imperative / stream
final device = FoldableDevice.instance;

await device.capabilities;                 // Future<FoldableCapabilities>, cached
device.stateStream;                        // Stream<FoldableState>, deduped
device.postureStream;                      // Stream<FoldPosture>, deduped
device.hingeAngleStream;                   // Stream<double>, throttled, opt-in
device.currentState;                       // FoldableState? — last known, sync

// Declarative — the primary surface most devs will touch
FoldableBuilder(
  builder: (context, state) => switch (state.posture) {
    FoldPosture.tabletop => TabletopLayout(),
    FoldPosture.closed   => CompactLayout(),
    _                    => FullLayout(),
  },
);

// InheritedWidget access, MediaQuery-shaped, as the brief envisioned
final posture = Foldable.of(context).posture;

// Effects — deliberately separate import so it reads as an advanced tool
import 'package:foldable_runtime/effects.dart';
HingeAngleBuilder(builder: (ctx, angle) => Transform.rotate(...));
```

**Design decision:** `hingeAngleStream` requires an explicit `device.enableAngleUpdates()` and is documented as "for effects, not layout." Layout via angle is possible but never the path of least resistance. This encodes Apple's guidance into the type system's ergonomics.

### 6.2 React Native

```ts
const { posture, hinge, display, capabilities } = useFoldableDevice();

// Narrow hooks to avoid re-rendering on angle churn
const posture = useFoldPosture();
const angle   = useHingeAngle({ enabled: true, throttleMs: 16 });

if (capabilities.sceneAccessory) { /* ... */ }
```

TurboModule + JSI, New Architecture only. Supporting the old bridge doubles the work for a shrinking audience; RN 0.80+ is New Arch by default. State ships over JSI as a plain object; the angle stream uses a native event emitter with native-side throttling so JS never sees 200Hz.

### 6.3 Naming
`FoldableDevice` reads well and matches the brief. `hinge_devices` as a repo name is fine; the **published package should be `foldable_runtime`** — "hinge" undersells it and buries it in search for "flutter foldable".

---

## 7. Platform implementation

### 7.1 Android (Kotlin)
- `SensorManager` + `Sensor.TYPE_HINGE_ANGLE` — registered lazily, unregistered on `ON_PAUSE`, `SENSOR_DELAY_UI` default. Never register at plugin attach.
- `androidx.window:window` — `WindowInfoTracker.windowLayoutInfo(activity)` for `FoldingFeature`. Requires an Activity, so the plugin must handle `ActivityAware` correctly and degrade to sensor-only when detached.
- `WindowAreaController` — capability detection only in v0.1; transfer gated behind v0.4.
- Display detection via `DisplayManager` + `Display.getDisplayId()` to distinguish inner/cover on Flip-class hardware.
- **No Samsung SDK dependency.** Everything Samsung-specific is reachable via AOSP APIs plus quirks data.
- Min SDK 21 for the package (no-op below 30 for angle, below 24 for WindowManager).

### 7.2 iOS (Swift)
- `UIHingeInteraction` on the root view for hinge status + angle; null check for non-Duo devices is the capability probe.
- `arrangement` / `region` from scene geometry drives posture and display features — **not** the angle. Apple's own layering.
- `sceneAccessory` + `CameraCaptureAccessory(isEnabled:)` surfaced in v0.3 as an opt-in Flutter/RN embedding surface — this is the highest-effort, highest-differentiation item in the whole roadmap.
- Deployment target: package builds on iOS 13+, foldable code paths compiled under `#available(iOS 27, *)`. An app on iOS 16 must compile and get `isFoldable == false`.

### 7.3 Everything else
Web, macOS, Windows, Linux: registered platform implementations returning static `isFoldable: false` capabilities. Cheap, and it means the package never breaks a multi-platform build — which is a real adoption blocker for Flutter packages.

---

## 8. Test and simulation harness

This is the differentiator; treat it as a P0 feature, not tooling.

- **`FoldableDevice.debugOverride(FoldableState)`** — inject any state at runtime. Ships in the main package (not a separate `_test` package) so devs can wire a debug menu into their app.
- **Emulator recipes** — documented `adb emu sensor set hinge_angle <deg>` and Android Studio foldable AVD profiles; scripts in `tool/`.
- **Golden-test kit** — `foldable_runtime_test` package with `pumpFoldable(tester, posture: ...)` for widget tests across all seven postures.
- **Duo simulator** notes for Xcode 27 once available to us.
- **Device quirk contribution flow** — a one-command report (`flutter run tool/report_device.dart`) that dumps raw sensor and window info as a pasteable GitHub issue, so the quirks table is crowdsourced. We will never own every foldable; the community fills the matrix.

---

## 9. Milestones

Deliberately re-scoped against the brief. The brief's v0.1 is roughly two weeks of work, not three days.

### v0.1 — "Posture, honestly" — target: this weekend
Flutter + Android only.
- Core model, capabilities, quirks-driven normalisation
- Posture from `FoldingFeature`, angle from sensor, fused
- `FoldableBuilder`, `Foldable.of(context)`, `postureStream`, gated `hingeAngleStream`
- No-op implementations for iOS/web/desktop so it compiles everywhere
- `debugOverride` + emulator docs
- Example app demonstrating flat / tabletop / book / closed
- **Ship criterion:** works on a Z Fold and Z Flip emulator, zero exceptions on a Pixel 8.

### v0.2 — "Cover screens" — +1 week
- Flip-class cover display detection, `flipClosed` posture
- Display info, active display, separating features
- Manifest lint + continuity documentation (the honest version of "Samsung support")
- Golden-test kit

### v0.3 — "Duo" — +2–3 weeks, hardware-gated
- iOS Hinge API, posture from arrangement/region
- Scene Accessory surface for Flutter (embedding a second `FlutterView` on the outer display) — **this is the risky one; timebox it and be willing to ship v0.3 without it**
- Blocked on: Xcode 27, and either a Duo simulator or a physical device on 2026-10-23.

### v0.4 — "React Native" — +2 weeks
- TurboModule, JSI, hooks, New Arch only
- Same spec, generated types, shared test vectors

### v0.5 — "Advanced displays"
- Rear display transfer with a documented state-restoration story
- Dual concurrent display

---

## 10. Success metrics

| Metric | 30 days | 90 days |
|---|---|---|
| pub.dev likes | 100 | 400 |
| pub points | 160/160 | 160/160 |
| GitHub stars | 200 | 800 |
| Devices in quirks table | 6 | 20 |
| Apps in the wild (self-reported) | 5 | 40 |
| Inbound (talks, consulting, hires) | 1 | 5 |

Pub points at 160/160 from day one is non-negotiable — it is the entire ranking algorithm and costs one afternoon of dartdoc, example, and analysis config.

---

## 11. Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Flutter team ships first-party foldable support | Medium | High | Stay complementary to `displayFeatures`, not competitive; own RN parity and the test harness |
| Duo APIs behave differently than the Tech Talk implies | High | Medium | Ship v0.1–v0.2 Android-only; do not pre-announce Duo support |
| Cannot embed a second FlutterView on the outer display | Medium | High | Timebox; degrade v0.3 to hinge + posture only, ship Scene Accessory in v0.6 |
| Angle sensor drains battery / gets us blamed for jank | Medium | High | Opt-in, throttled, auto-unregistered — and say so loudly in the README |
| Rear-display transfer kills Flutter engine state | High | High | Deferred to v0.5 behind an explicit flag with a written warning |
| Nobody adopts because foldables are 2% of market | Medium | Medium | Accept it — see §12; this package's ROI is positional |
| Existing packages add Duo first | Medium | Medium | Speed. Ship Android v0.1 within days of the Duo announcement while attention is peaking |

---

## 12. The business critique

Straight version, because the roadmap above is worth nothing without it.

**This package will not make money directly.** Open-source developer infrastructure for a 2%-share form factor has no viable direct monetisation. Sponsorware caps out in the low hundreds per month. Do not build this expecting revenue.

**Build it for these three returns instead, and be deliberate about which one you're optimising:**

1. **Positional authority.** "The person who built the foldable layer for Flutter and React Native" is a durable, searchable identity, and it arrives at the exact moment Apple legitimises the category. That is worth more than the package. It compounds into conference talks, consulting rates, and the kind of inbound where the other side has already decided.

2. **A distribution asset for something you sell later.** The package is free; a **Foldable UI Kit** — pre-built tabletop camera controls, Flex-Mode video players, book-mode readers, cover-screen widgets — is a $79–$149 product with a captive audience that arrives pre-qualified by the free package. That is the actual monetisation path, and the PRD above should be read as "build the top of that funnel."

3. **A recruiting/credibility artifact.** Cross-platform native plugin work with a clean capability model is a strong signal to exactly the buyers you want.

**What would make me not build it:** if the goal is revenue this quarter. Then this is a distraction and the two weeks belong somewhere with pricing power.

**What makes me build it anyway:** the timing is genuinely rare. Platform-capability convergence windows like this open maybe twice a decade per category, and being first with the correct abstraction — not the first with *an* abstraction — is how you get named as the default. But be honest that you are buying positioning, not revenue.

**Sharpest strategic note:** the demo matters more than the code. A 30-second video of the same app state flowing between inner display, Flex Mode, and cover screen — on a Duo, on launch week — will out-distribute six months of good commits. Budget for the demo as a first-class deliverable, not an afterthought.

---

## 13. Open questions

1. Do you have physical access to a Z Fold/Flip, or are we emulator-only for v0.1? This changes the ship criterion.
2. Is a Duo preordered? v0.3's date depends entirely on 2026-10-23.
3. Is the UI Kit (§12.2) in scope as a business, or is this purely a positioning play? It changes how much we invest in the example app.
4. Solo build, or is anyone else on this? The RN milestone is the natural parallel track.
5. Do we announce at v0.1 (Android-only, honest) or hold until v0.3 (Duo, complete)? Recommendation: announce v0.1 now — attention decays faster than the package matures.

---

## Appendix A — References

- Android: `Sensor.TYPE_HINGE_ANGLE`, API 30+
- Jetpack WindowManager `FoldingFeature`, `WindowAreaController`
- Apple Tech Talk 111464 — "Leverage multiple displays and scenes on iPhone Duo": `onHingeChange`, `UIHingeInteraction`, `hinge.angle`, `hinge.status`, `sceneAccessory`, `CameraCaptureAccessory(isEnabled:)`, `UIWindowSceneActivation`, arrangement/region APIs
- Flutter `MediaQuery.displayFeatures`, `TwoPane`
- Prior art: `split_screen` (Dart), `@logicwind/react-native-fold-detection`
