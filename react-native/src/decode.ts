import {
  ActiveDisplay,
  DisplayInfo,
  FeatureOcclusion,
  FoldableDisplayFeature,
} from './model/display';
import { FoldableCapabilities, NO_CAPABILITIES } from './model/capabilities';
import { FoldAxis, Hinge } from './model/hinge';
import { FoldableState } from './model/state';
import { FoldingFeatureState, PostureThresholds, hingeStatusFor, resolvePosture } from './model/resolver';
import { HingeQuirk, normalizeAngle } from './model/quirks';

/** An untyped payload straight off the native event channel. */
export type RawEvent = Record<string, unknown>;

function asNumber(value: unknown): number | null {
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
}

function asAxis(value: unknown): FoldAxis | null {
  return value === 'horizontal' || value === 'vertical' ? value : null;
}

function asFeatureState(value: unknown): FoldingFeatureState | null {
  return value === 'flat' || value === 'halfOpened' ? value : null;
}

function asActiveDisplay(value: unknown): ActiveDisplay {
  switch (value) {
    case 'inner':
    case 'outer':
    case 'cover':
    case 'rear':
      return value;
    default:
      return ActiveDisplay.Unknown;
  }
}

/** Decodes the native capability reply, keeping unknown keys readable. */
export function decodeCapabilities(reply: RawEvent): FoldableCapabilities {
  const raw: Record<string, boolean> = {};
  for (const [key, value] of Object.entries(reply)) {
    if (typeof value === 'boolean') raw[key] = value;
  }

  return {
    isFoldable: raw.isFoldable ?? false,
    hingeAngleSensor: raw.hingeAngleSensor ?? false,
    foldingFeature: raw.foldingFeature ?? false,
    outerDisplay: raw.outerDisplay ?? false,
    sceneAccessory: raw.sceneAccessory ?? false,
    rearDisplayTransfer: raw.rearDisplayTransfer ?? false,
    dualConcurrent: raw.dualConcurrent ?? false,
    specVersion: asNumber(reply.specVersion) ?? NO_CAPABILITIES.specVersion,
    raw,
  };
}

function decodeFeatures(
  raw: unknown,
  orientation: FoldAxis | null,
): FoldableDisplayFeature[] {
  if (!Array.isArray(raw)) return [];
  const features: FoldableDisplayFeature[] = [];

  for (const entry of raw) {
    if (typeof entry !== 'object' || entry === null) continue;
    const f = entry as RawEvent;
    features.push({
      bounds: {
        left: asNumber(f.left) ?? 0,
        top: asNumber(f.top) ?? 0,
        right: asNumber(f.right) ?? 0,
        bottom: asNumber(f.bottom) ?? 0,
      },
      isSeparating: f.isSeparating === true,
      occlusion:
        f.occlusion === 'full' || f.occlusion === 'none'
          ? (f.occlusion as FeatureOcclusion)
          : FeatureOcclusion.Unknown,
      orientation,
    });
  }

  return features;
}

/** Everything the decoder needs to know about the current device. */
export interface DecodeContext {
  readonly quirk: HingeQuirk;
  readonly capabilities: FoldableCapabilities;
  readonly thresholds: PostureThresholds;
}

/**
 * Turns one native payload into a complete state.
 *
 * Mirrors the Dart decoder, including the deduction that a device which is
 * shut and still drawing must be drawing on an outer panel.
 */
export function decodeState(
  event: RawEvent,
  context: DecodeContext,
): { state: FoldableState; learnedOuterDisplay: boolean } {
  const orientation = asAxis(event.featureOrientation);
  const rawAngle = asNumber(event.hingeAngle);
  const angle = normalizeAngle(rawAngle, context.quirk);

  const isShut =
    angle != null && angle <= context.thresholds.closedAtOrBelow;

  const capabilities: FoldableCapabilities =
    isShut && !context.capabilities.outerDisplay
      ? {
          ...context.capabilities,
          outerDisplay: true,
          raw: { ...context.capabilities.raw, outerDisplay: true },
        }
      : context.capabilities;

  const posture = resolvePosture(
    {
      featureState: asFeatureState(event.featureState),
      featureOrientation: orientation,
      angle,
      hasOuterDisplay: capabilities.outerDisplay,
    },
    context.thresholds,
  );

  const hinge: Hinge = {
    angle,
    rawAngle,
    range: context.quirk.range,
    status: hingeStatusFor(angle, context.thresholds),
    orientation,
    resolution: context.quirk.resolution,
    detentValues: context.quirk.detentValues,
  };

  const display: DisplayInfo = {
    active: asActiveDisplay(event.activeDisplay),
    features: decodeFeatures(event.features, orientation),
    width: asNumber(event.windowWidth),
    height: asNumber(event.windowHeight),
  };

  return {
    state: {
      posture,
      hinge,
      display,
      capabilities,
      timestamp: Date.now(),
    },
    learnedOuterDisplay: isShut,
  };
}
