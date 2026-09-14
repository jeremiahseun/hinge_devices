# core-android

The Android hardware code, held once and vendored into both packages.

```
core-android/src/main/kotlin/dev/jeremiahseun/hinge_devices/core/
    HingeSensorSource.kt     TYPE_HINGE_ANGLE, two sampling rates, staleness
    WindowLayoutSource.kt    Jetpack WindowManager folding features
    DisplaySource.kt         cover/outer display identification
```

**This is the source of truth. Edit here, never in a package.** Then:

```bash
dart run tool/sync_shared.dart          # vendor into both packages
dart run tool/sync_shared.dart --check  # what CI runs
```

The copies in `flutter/android/` and `react-native/android/` carry a generated
header and are committed on purpose. CI fails if they drift from this folder.

## Why vendoring, and not a Maven artifact

A published package has to be self-contained. The pub.dev archive ships only
`flutter/android/`; the npm tarball ships only `react-native/android/`. Neither
can reach up into this folder at build time, so a consumer building either
package needs the Kotlin physically present inside it.

Publishing this as `dev.jeremiahseun:hinge-devices-core` on Maven Central is
the textbook answer and the right long-term move. It needs an OSSRH account
and a GPG signing pipeline, and until that exists the drift check buys the
same guarantee: one place to edit, and a build failure if the copies disagree.

## Why it is worth sharing at all

Every bug found on real hardware so far has been in exactly this code:

- the hinge sensor holding a stale reading across an unregister, which left an
  opened Z Flip stuck on its closed layout
- the sensor being torn down during the configuration change that unfolding
  *is*, so posture went quiet at the one moment it mattered
- reading window and display APIs from the sensor's callback thread, which
  threw inside `onSensorChanged` and silently killed every angle update
- reflecting onto `Display.getType()`, hidden API that has been blocked since
  Android 9 and fails closed

Four bugs, one device, four days. Shared, each of those was fixed once.
