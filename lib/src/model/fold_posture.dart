/// The physical posture of a foldable device.
///
/// Postures form a shallow hierarchy: [tabletop] and [book] are *refinements*
/// of [halfOpened], and [flipClosed] is a refinement of [closed]. Use
/// [FoldPostureX.isHalfOpened] and [FoldPostureX.isClosed] so your code keeps
/// working when a future release adds a new refinement.
enum FoldPosture {
  /// No signal yet, or the device does not report posture.
  unknown,

  /// Fully open — one continuous surface. Apple reports this as `fullyOpen`.
  flat,

  /// Partially open, with no orientation information available.
  halfOpened,

  /// Partially open with a horizontal fold: the "laptop"/Flex Mode posture.
  tabletop,

  /// Partially open with a vertical fold: the "book" posture.
  book,

  /// Folded shut, with no usable outer display reported.
  closed,

  /// Folded shut on a device that exposes a usable cover/outer display.
  flipClosed;
}

/// The three states every foldable app has to handle.
///
/// [FoldPosture] is deliberately finer-grained than most apps need, and a
/// `switch` over it invites a subtle bug: matching `FoldPosture.closed`
/// exactly silently drops [FoldPosture.flipClosed], so a Flip on its cover
/// screen falls through to the opened layout. Switch on this instead when you
/// only need the coarse answer — it is exhaustive, so the analyzer catches
/// what you missed.
///
/// ```dart
/// switch (state.posture.coarse) {
///   CoarsePosture.open    => FullLayout(),
///   CoarsePosture.halfOpen => TabletopLayout(),
///   CoarsePosture.closed  => CompactLayout(),
/// }
/// ```
enum CoarsePosture {
  /// The device presents one continuous surface, or posture is not yet known.
  ///
  /// Unknown maps here on purpose: an ordinary phone and a device that has
  /// not reported yet should both render your normal layout.
  open,

  /// The device is partially folded, in any orientation.
  halfOpen,

  /// The device is shut, with or without a usable cover display.
  closed,
}

/// Hierarchy helpers for [FoldPosture].
extension FoldPostureX on FoldPosture {
  /// True for [FoldPosture.halfOpened] and every refinement of it.
  bool get isHalfOpened =>
      this == FoldPosture.halfOpened ||
      this == FoldPosture.tabletop ||
      this == FoldPosture.book;

  /// True for [FoldPosture.closed] and every refinement of it.
  bool get isClosed =>
      this == FoldPosture.closed || this == FoldPosture.flipClosed;

  /// True when the device presents a single continuous surface.
  bool get isFlat => this == FoldPosture.flat;

  /// True when posture could not be determined.
  bool get isUnknown => this == FoldPosture.unknown;

  /// Collapses this posture to the three states most apps branch on.
  ///
  /// Prefer switching on this over switching on [FoldPosture] directly: it is
  /// exhaustive, so adding a posture in a later release becomes an analyzer
  /// error in your app rather than a layout that silently stops appearing.
  CoarsePosture get coarse => switch (this) {
        FoldPosture.closed || FoldPosture.flipClosed => CoarsePosture.closed,
        FoldPosture.halfOpened ||
        FoldPosture.tabletop ||
        FoldPosture.book =>
          CoarsePosture.halfOpen,
        FoldPosture.flat || FoldPosture.unknown => CoarsePosture.open,
      };
}
