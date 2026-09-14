/** The angular convention a device's hinge sensor reports in. */
export const HingeAngleRange = {
  /** `0` closed to `180` flat — the common case. */
  ZeroTo180: 'zeroTo180',
  /** `0` closed to `360` fully reversed. */
  ZeroTo360: 'zeroTo360',
  /** Convention not known; the raw value is used unchanged. */
  Unknown: 'unknown',
} as const;
export type HingeAngleRange =
  (typeof HingeAngleRange)[keyof typeof HingeAngleRange];

/** A coarse hinge state, mirroring Apple's `hinge.status`. */
export const HingeStatus = {
  Closed: 'closed',
  PartiallyOpen: 'partiallyOpen',
  FullyOpen: 'fullyOpen',
  Unknown: 'unknown',
} as const;
export type HingeStatus = (typeof HingeStatus)[keyof typeof HingeStatus];

/**
 * How finely a device's hinge sensor actually reports.
 *
 * Nothing in Android's API says whether `TYPE_HINGE_ANGLE` sweeps through
 * intermediate values or only fires at fixed positions, and no vendor
 * documents it — but it decides whether a continuous angle-driven effect is
 * buildable at all. A Galaxy Z Flip 5 reports exactly three values, so an
 * effect that maps hinge angle onto a slider has three states there, not a
 * smooth range.
 */
export const HingeResolution = {
  /** The sensor sweeps: intermediate angles arrive as the device moves. */
  Continuous: 'continuous',
  /** The sensor only reports at fixed positions. */
  Detents: 'detents',
  /**
   * Not yet known for this device. Treat as continuous only if you degrade
   * gracefully; the safe assumption is that it may be detents.
   */
  Unknown: 'unknown',
} as const;
export type HingeResolution =
  (typeof HingeResolution)[keyof typeof HingeResolution];

/** The fold's axis, when a folding feature reports one. */
export type FoldAxis = 'horizontal' | 'vertical';

/**
 * Hinge readings for the current device.
 *
 * `angle` is `null` on devices without a hinge-angle sensor, which is most
 * devices — always null-check it rather than defaulting to `0`. `0` means
 * fully closed, which is a very different claim from "we don't know".
 */
export interface Hinge {
  /** Normalised angle in degrees: `0` fully closed, `180` fully flat. */
  readonly angle: number | null;
  /** The untouched platform value, before normalisation. */
  readonly rawAngle: number | null;
  /** The convention `rawAngle` was reported in. */
  readonly range: HingeAngleRange;
  /** Coarse hinge state. */
  readonly status: HingeStatus;
  /** The fold's axis, when a folding feature reports one. */
  readonly orientation: FoldAxis | null;
  /** How finely this device's sensor reports. */
  readonly resolution: HingeResolution;
  /** The fixed positions a detent-reporting device produces. */
  readonly detentValues: readonly number[];
}

/** A hinge with no readings, for devices with no sensor. */
export const NO_HINGE: Hinge = Object.freeze({
  angle: null,
  rawAngle: null,
  range: HingeAngleRange.Unknown,
  status: HingeStatus.Unknown,
  orientation: null,
  resolution: HingeResolution.Unknown,
  detentValues: Object.freeze([]),
});

/**
 * Whether a continuous angle-driven effect is worth building here.
 *
 * False on a device that only reports at detents — prefer posture-driven UI
 * there, or accept that your effect will snap between a few positions.
 */
export function supportsContinuousEffects(hinge: Hinge): boolean {
  return hinge.resolution === HingeResolution.Continuous;
}
