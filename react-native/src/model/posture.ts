/**
 * The physical posture of a foldable device.
 *
 * Postures form a shallow hierarchy: `tabletop` and `book` are *refinements*
 * of `halfOpened`, and `flipClosed` is a refinement of `closed`. Use
 * {@link isHalfOpened}, {@link isClosed} or {@link coarsePosture} so your code
 * keeps working when a future release adds a refinement.
 */
export const FoldPosture = {
  /** No signal yet, or the device does not report posture. */
  Unknown: 'unknown',
  /** Fully open — one continuous surface. Apple reports this as `fullyOpen`. */
  Flat: 'flat',
  /** Partially open, with no orientation information available. */
  HalfOpened: 'halfOpened',
  /** Partially open with a horizontal fold: the laptop/Flex Mode posture. */
  Tabletop: 'tabletop',
  /** Partially open with a vertical fold: the book posture. */
  Book: 'book',
  /** Folded shut, with no usable outer display reported. */
  Closed: 'closed',
  /** Folded shut on a device that exposes a usable cover/outer display. */
  FlipClosed: 'flipClosed',
} as const;

export type FoldPosture = (typeof FoldPosture)[keyof typeof FoldPosture];

/**
 * The three states every foldable app has to handle.
 *
 * `FoldPosture` is deliberately finer-grained than most apps need, and
 * switching on it invites a subtle bug: handling `'closed'` alone silently
 * drops `'flipClosed'`, so a Flip on its cover screen falls through to the
 * opened layout. Switch on this instead when you only need the coarse answer.
 */
export const CoarsePosture = {
  /**
   * One continuous surface, or posture not yet known.
   *
   * Unknown maps here on purpose: an ordinary phone and a device that has not
   * reported yet should both render your normal layout.
   */
  Open: 'open',
  /** Partially folded, in any orientation. */
  HalfOpen: 'halfOpen',
  /** Shut, with or without a usable cover display. */
  Closed: 'closed',
} as const;

export type CoarsePosture = (typeof CoarsePosture)[keyof typeof CoarsePosture];

/** True for `halfOpened` and every refinement of it. */
export function isHalfOpened(posture: FoldPosture): boolean {
  return (
    posture === FoldPosture.HalfOpened ||
    posture === FoldPosture.Tabletop ||
    posture === FoldPosture.Book
  );
}

/** True for `closed` and every refinement of it. */
export function isClosed(posture: FoldPosture): boolean {
  return posture === FoldPosture.Closed || posture === FoldPosture.FlipClosed;
}

/**
 * Collapses a posture to the three states most apps branch on.
 *
 * Prefer switching on this over switching on `FoldPosture` directly: a
 * posture added in a later release keeps mapping to a sensible coarse state
 * rather than silently falling through your default branch.
 */
export function coarsePosture(posture: FoldPosture): CoarsePosture {
  switch (posture) {
    case FoldPosture.Closed:
    case FoldPosture.FlipClosed:
      return CoarsePosture.Closed;
    case FoldPosture.HalfOpened:
    case FoldPosture.Tabletop:
    case FoldPosture.Book:
      return CoarsePosture.HalfOpen;
    case FoldPosture.Flat:
    case FoldPosture.Unknown:
      return CoarsePosture.Open;
  }
}
