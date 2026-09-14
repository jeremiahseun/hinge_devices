import { DisplayInfo, EMPTY_DISPLAY } from './display';
import { FoldableCapabilities, NO_CAPABILITIES } from './capabilities';
import { FoldPosture } from './posture';
import { Hinge, NO_HINGE } from './hinge';

/** A single, complete description of the device's physical state. */
export interface FoldableState {
  /** The device's physical posture. Lay out against this. */
  readonly posture: FoldPosture;
  /** Hinge readings. Use these for effects, not layout. */
  readonly hinge: Hinge;
  /** The display the app currently occupies. */
  readonly display: DisplayInfo;
  /** What this device can do. */
  readonly capabilities: FoldableCapabilities;
  /** When this state was produced, in milliseconds since the epoch. */
  readonly timestamp: number;
}

/** The state reported for a device that does not fold. */
export const RIGID_DEVICE: FoldableState = Object.freeze({
  posture: FoldPosture.Unknown,
  hinge: NO_HINGE,
  display: EMPTY_DISPLAY,
  capabilities: NO_CAPABILITIES,
  timestamp: 0,
});

/**
 * Whether two states would produce the same layout.
 *
 * Ignores timestamp and hinge angle, so consecutive states that differ only
 * by an angle wiggle compare equal. Emitting a layout change sixty times a
 * second because the angle moved is the classic performance mistake in this
 * category.
 */
export function sameLayout(a: FoldableState, b: FoldableState): boolean {
  return (
    a.posture === b.posture &&
    a.hinge.status === b.hinge.status &&
    a.hinge.orientation === b.hinge.orientation &&
    a.display.active === b.display.active &&
    a.display.width === b.display.width &&
    a.display.height === b.display.height &&
    a.display.features.length === b.display.features.length &&
    a.capabilities.isFoldable === b.capabilities.isFoldable &&
    a.capabilities.outerDisplay === b.capabilities.outerDisplay
  );
}
