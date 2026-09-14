import { FoldAxis, HingeStatus } from './hinge';
import { FoldPosture } from './posture';

/** The folding-feature state a platform reports, independent of angle. */
export const FoldingFeatureState = {
  /** The device presents one continuous surface. */
  Flat: 'flat',
  /** The device is partially folded. */
  HalfOpened: 'halfOpened',
} as const;
export type FoldingFeatureState =
  (typeof FoldingFeatureState)[keyof typeof FoldingFeatureState];

/**
 * Angle boundaries used to derive posture when no folding feature is
 * available.
 *
 * Hinge conventions differ between vendors, so these are never hard-coded
 * into the derivation logic.
 */
export interface PostureThresholds {
  /** Angles at or below this value are treated as closed. */
  readonly closedAtOrBelow: number;
  /** Angles at or above this value are treated as flat. */
  readonly flatAtOrAbove: number;
}

/** Closed below 15 degrees, flat above 165. */
export const STANDARD_THRESHOLDS: PostureThresholds = Object.freeze({
  closedAtOrBelow: 15,
  flatAtOrAbove: 165,
});

/** The signals a platform can provide for one moment in time. */
export interface PostureSignals {
  readonly featureState?: FoldingFeatureState | null;
  readonly featureOrientation?: FoldAxis | null;
  readonly angle?: number | null;
  readonly hasOuterDisplay?: boolean;
}

/**
 * Derives posture from the signals a platform provides.
 *
 * This mirrors the Dart implementation exactly, and both run the shared
 * vectors in `spec/posture_vectors.json` — that file is what stops the two
 * drifting.
 *
 * Ordering, and why:
 *
 * 1. A closed angle wins. `closed` is the one posture no folding feature
 *    reports, and a Flip running on its cover screen can still report a
 *    feature, so treating that feature as proof the device is open puts a
 *    shut phone on its opened layout.
 * 2. Otherwise the folding feature decides. Both Android's and Apple's own
 *    guidance is that layout follows the folding feature; angle is for
 *    effects.
 * 3. Angle is the fallback when no folding feature exists at all.
 *
 * The stale-reading hazard in rule 1 is handled at the source rather than
 * here: the native sensor clears its reading when unregistered, so a stale
 * angle arrives as `null`, and `null` never resolves to closed.
 */
export function resolvePosture(
  signals: PostureSignals,
  thresholds: PostureThresholds = STANDARD_THRESHOLDS,
): FoldPosture {
  const { featureState, featureOrientation, angle } = signals;
  const hasOuterDisplay = signals.hasOuterDisplay ?? false;

  if (angle != null && angle <= thresholds.closedAtOrBelow) {
    return hasOuterDisplay ? FoldPosture.FlipClosed : FoldPosture.Closed;
  }

  if (featureState != null) {
    if (featureState === FoldingFeatureState.Flat) {
      return FoldPosture.Flat;
    }
    // A horizontal fold splits the window top/bottom: tabletop.
    // A vertical fold splits it left/right: book.
    if (featureOrientation === 'horizontal') return FoldPosture.Tabletop;
    if (featureOrientation === 'vertical') return FoldPosture.Book;
    return FoldPosture.HalfOpened;
  }

  if (angle != null) {
    return angle >= thresholds.flatAtOrAbove
      ? FoldPosture.Flat
      : FoldPosture.HalfOpened;
  }

  return FoldPosture.Unknown;
}

/** Derives the coarse hinge status that mirrors Apple's `hinge.status`. */
export function hingeStatusFor(
  angle: number | null | undefined,
  thresholds: PostureThresholds = STANDARD_THRESHOLDS,
): HingeStatus {
  if (angle == null) return HingeStatus.Unknown;
  if (angle <= thresholds.closedAtOrBelow) return HingeStatus.Closed;
  if (angle >= thresholds.flatAtOrAbove) return HingeStatus.FullyOpen;
  return HingeStatus.PartiallyOpen;
}
