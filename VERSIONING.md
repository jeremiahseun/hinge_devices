# Versioning

`hinge_devices` ships to two ecosystems under one name: **pub.dev** for
Flutter and **npm** for React Native. They are two implementations of one
specification, and a developer reading the Flutter docs and a developer
reading the React Native docs must be reading about the same behaviour.

One name was a deliberate choice. `dart pub add hinge_devices` and
`npm i hinge_devices` should not be two different products.

## The rule

**Major and minor are shared. Patch is independent.**

```
pub.dev  hinge_devices  0.3.0  ─┐
                                ├─ same major.minor: same API, same semantics
npm      hinge_devices  0.3.0  ─┘

pub.dev  hinge_devices  0.3.2   ← a Dart-only bug fix
npm      hinge_devices  0.3.0   ← untouched, still the same API
```

If you know one package's major and minor, you know what the other one does.

### What each part means

| Bump | When | Released as |
|---|---|---|
| **Major** | A breaking change to the shared model — a removed posture, a renamed capability, a changed resolution rule | Both packages, together |
| **Minor** | A new capability, a new posture, a new stream — anything that changes the spec | Both packages, together |
| **Patch** | A bug fix, a device quirk, a docs change, a platform-specific fix | Only the package that needed it |

### The test for "is this a minor or a patch"

Ask: **would the React Native docs need to change?**

- Yes → minor, and both packages ship.
- No → patch, and only the affected package ships.

A quirk entry for a new device is a patch: the model did not change. Adding
`HingeResolution` was a minor, because it changed what both packages report.

### Why not just version them independently

Because the promise of this package is that posture means the same thing
everywhere. The moment pub.dev is on 0.5 and npm is on 0.3, nobody can answer
"does my React Native app get `flipClosed`?" without reading two changelogs.
Shared major.minor makes that question free.

## Enforcement

`spec/version.json` is the single source of truth. Every package manifest is
checked against it:

```bash
dart run tool/check_versions.dart
```

This runs in CI on every push, and fails the build when a manifest and the
spec disagree — so a package cannot be published at a version that breaks the
contract above.

To cut a release:

Packages are keyed by ecosystem, since they share a name:

```bash
# a shared minor: both ecosystems go to 0.4.0
dart run tool/check_versions.dart --set-minor 4

# a Dart-only patch: pub.dev goes to 0.3.1, npm untouched
dart run tool/check_versions.dart --set-patch dart 1

# a React Native-only patch
dart run tool/check_versions.dart --set-patch react_native 1
```

### Packages that do not exist yet

`react_native` is registered in `spec/version.json` with `"pending": true`. It
is reserved at the current version and skipped by the check until
`react-native/package.json` appears — at which point the check *fails* until
`pending` is removed, so a new package cannot quietly join at the wrong
version.

Both commands rewrite `spec/version.json` and every affected manifest, so the
two can never drift by hand.

## Before 1.0

The package is pre-1.0 while iOS and React Native are unbuilt. Under
[pub.dev's semantics](https://dart.dev/tools/pub/versioning) a `0.x` minor
bump may break API — and it has, more than once, because real hardware keeps
teaching us things. 1.0.0 is the release where:

- iPhone Duo support ships and the model has survived contact with a second OS
- React Native ships and the spec has survived contact with a second framework
- No posture, capability or resolution rule has changed for a full minor cycle

Until then, pin a minor:

```yaml
# pubspec.yaml
hinge_devices: ^0.3.0
```

```json
// package.json
"hinge_devices": "~0.3.0"
```
