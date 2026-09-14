/**
 * hinge_devices — a unified posture, hinge and display model for foldable
 * devices.
 *
 * The same model ships to pub.dev for Flutter and npm for React Native, and
 * both run the conformance vectors in `spec/posture_vectors.json`, so
 * `tabletop` means the same thing on both.
 */
export { FoldableDevice } from './device';

export {
  useFoldableDevice,
  useFoldPosture,
  useCoarsePosture,
  useFoldableCapabilities,
  useHingeAngle,
  useFoldableDebugOverride,
} from './hooks';
export type { HingeAngleOptions } from './hooks';

export {
  CoarsePosture,
  FoldPosture,
  coarsePosture,
  isClosed,
  isHalfOpened,
} from './model/posture';

export {
  HingeAngleRange,
  HingeResolution,
  HingeStatus,
  NO_HINGE,
  supportsContinuousEffects,
} from './model/hinge';
export type { FoldAxis, Hinge } from './model/hinge';

export {
  ActiveDisplay,
  EMPTY_DISPLAY,
  FeatureOcclusion,
  isSeparating,
} from './model/display';
export type { DisplayInfo, FoldableDisplayFeature, Rect } from './model/display';

export { NO_CAPABILITIES, capability } from './model/capabilities';
export type { FoldableCapabilities } from './model/capabilities';

export { RIGID_DEVICE, sameLayout } from './model/state';
export type { FoldableState } from './model/state';

export {
  FoldingFeatureState,
  STANDARD_THRESHOLDS,
  hingeStatusFor,
  resolvePosture,
} from './model/resolver';
export type { PostureSignals, PostureThresholds } from './model/resolver';

export {
  ASSUMED_QUIRK,
  lookupQuirk,
  normalizeAngle,
  registerQuirk,
  resetQuirks,
} from './model/quirks';
export type { HingeQuirk } from './model/quirks';
