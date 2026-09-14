# Versioning

`foldable_runtime` (Dart) and `@foldable/runtime` (npm) are two implementations
of one specification. A developer reading the Flutter docs and a developer
reading the React Native docs must be reading about the same behaviour.

## The rule

**Major and minor are shared. Patch is independent.**

```
foldable_runtime      0.3.0  ─┐
                              ├─ same major.minor: same API, same semantics
@foldable/runtime     0.3.0  ─┘

foldable_runtime      0.3.2   ← a Dart-only bug fix
@foldable/runtime     0.3.0   ← untouched, still the same API
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
everywhere. The moment `foldable_runtime` 0.5 and `@foldable/runtime` 0.3 are
both current, nobody can answer "does my React Native app get `flipClosed`?"
without reading two changelogs. Shared major.minor makes that question free.

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

```bash
# a shared minor: both packages go to 0.4.0
dart run tool/check_versions.dart --set-minor 4

# a Dart-only patch: foldable_runtime goes to 0.3.1, npm untouched
dart run tool/check_versions.dart --set-patch foldable_runtime 1
```

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

Until then, pin a minor: `foldable_runtime: ^0.3.0`.
