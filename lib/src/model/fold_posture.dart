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
}
