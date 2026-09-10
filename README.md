# foldable_runtime

A unified posture, hinge, and display model for foldable devices — Flutter and React Native, Android and iOS.

> Status: pre-implementation. See [PRD.md](PRD.md) for the full product spec, roadmap, and critique.

```dart
FoldableBuilder(
  builder: (context, state) => switch (state.posture) {
    FoldPosture.tabletop => TabletopLayout(),
    FoldPosture.closed   => CompactLayout(),
    _                    => FullLayout(),
  },
);
```

Not a hinge-angle wrapper. The point is the capability model, the posture hierarchy,
cross-framework parity, and a simulation harness that works without a $2,000 device.
