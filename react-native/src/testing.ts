import { FoldableDevice } from './device';
import { ActiveDisplay, FoldableDisplayFeature } from './model/display';
import { FoldableCapabilities } from './model/capabilities';
import { FoldPosture, isClosed } from './model/posture';
import { HingeAngleRange, HingeResolution, HingeStatus } from './model/hinge';
import { FoldableState } from './model/state';

/** Capabilities a synthetic foldable reports. */
export const TEST_CAPABILITIES: FoldableCapabilities = Object.freeze({
  isFoldable: true,
  hingeAngleSensor: true,
  foldingFeature: true,
  outerDisplay: true,
  sceneAccessory: false,
  rearDisplayTransfer: false,
  dualConcurrent: false,
  specVersion: 1,
  raw: Object.freeze({
    isFoldable: true,
    hingeAngleSensor: true,
    foldingFeature: true,
    outerDisplay: true,
  }),
});

function defaultAngle(posture: FoldPosture): number {
  if (isClosed(posture)) return 0;
  if (posture === FoldPosture.Flat || posture === FoldPosture.Unknown) {
    return 180;
  }
  return 90;
}

function statusFor(posture: FoldPosture): HingeStatus {
  if (isClosed(posture)) return HingeStatus.Closed;
  if (posture === FoldPosture.Flat) return HingeStatus.FullyOpen;
  if (posture === FoldPosture.Unknown) return HingeStatus.Unknown;
  return HingeStatus.PartiallyOpen;
}

/**
 * Builds a realistic state for a posture, so a test sees the display feature
 * and hinge reading a real device would have produced.
 */
export function stateFor(
  posture: FoldPosture,
  options: {
    angle?: number;
    width?: number;
    height?: number;
    capabilities?: FoldableCapabilities;
  } = {},
): FoldableState {
  const width = options.width ?? 800;
  const height = options.height ?? 900;
  const angle = options.angle ?? defaultAngle(posture);

  const orientation =
    posture === FoldPosture.Tabletop
      ? ('horizontal' as const)
      : posture === FoldPosture.Book
        ? ('vertical' as const)
        : null;

  const features: FoldableDisplayFeature[] =
    orientation == null
      ? []
      : [
          {
            bounds:
              orientation === 'horizontal'
                ? { left: 0, top: height / 2 - 1, right: width, bottom: height / 2 + 1 }
                : { left: width / 2 - 1, top: 0, right: width / 2 + 1, bottom: height },
            isSeparating: true,
            occlusion: 'full',
            orientation,
          },
        ];

  return {
    posture,
    hinge: {
      angle,
      rawAngle: angle,
      range: HingeAngleRange.ZeroTo180,
      status: statusFor(posture),
      orientation,
      resolution: HingeResolution.Unknown,
      detentValues: [],
    },
    display: {
      active: isClosed(posture) ? ActiveDisplay.Cover : ActiveDisplay.Inner,
      features,
      width,
      height,
    },
    capabilities: options.capabilities ?? TEST_CAPABILITIES,
    timestamp: Date.now(),
  };
}

/**
 * Puts the device under test into a posture.
 *
 * Uses the same debug-override path an app can wire to its own debug menu,
 * so what a test exercises is what a developer can exercise by hand.
 */
export function setTestPosture(
  posture: FoldPosture,
  options?: Parameters<typeof stateFor>[1],
): void {
  FoldableDevice.debugOverride(stateFor(posture, options));
}

/** Hands control back to the platform and clears device state. */
export function resetTestDevice(): void {
  FoldableDevice.debugOverride(null);
  FoldableDevice.resetForTesting();
}
