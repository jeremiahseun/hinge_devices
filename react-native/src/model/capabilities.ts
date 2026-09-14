/**
 * What this device can actually do.
 *
 * Branch on capabilities, never on brand, model or OS version. Unknown
 * capabilities from a newer native implementation stay readable through
 * {@link capability}, so an app built against this version keeps working on
 * hardware that does not exist yet.
 */
export interface FoldableCapabilities {
  readonly isFoldable: boolean;
  /**
   * Whether a hinge-angle sensor is present. Independent of
   * {@link foldingFeature}: a device may have one, both, or neither.
   */
  readonly hingeAngleSensor: boolean;
  /** Whether the platform reports folding-feature geometry. */
  readonly foldingFeature: boolean;
  /** Whether a cover or outer display exists. */
  readonly outerDisplay: boolean;
  /**
   * Whether the app can render to a second display while the main UI stays on
   * the inner one.
   */
  readonly sceneAccessory: boolean;
  /** Whether the app can be transferred to a rear display. */
  readonly rearDisplayTransfer: boolean;
  /** Whether both displays can be driven at once. */
  readonly dualConcurrent: boolean;
  /** The capability-spec version the native implementation reported. */
  readonly specVersion: number;
  /**
   * Every capability the platform reported, including ones this version of
   * the package has no typed field for.
   */
  readonly raw: Readonly<Record<string, boolean>>;
}

/**
 * Everything off — the correct answer for the overwhelming majority of
 * devices, and the value returned on unsupported platforms.
 */
export const NO_CAPABILITIES: FoldableCapabilities = Object.freeze({
  isFoldable: false,
  hingeAngleSensor: false,
  foldingFeature: false,
  outerDisplay: false,
  sceneAccessory: false,
  rearDisplayTransfer: false,
  dualConcurrent: false,
  specVersion: 1,
  raw: Object.freeze({}),
});

/**
 * Reads a capability by name, falling back to the raw map for capabilities
 * this package version has no typed field for.
 *
 * Every foldable library that hard-codes its capability list dies on the next
 * hardware generation. This is the escape hatch.
 */
export function capability(
  capabilities: FoldableCapabilities,
  key: string,
): boolean {
  switch (key) {
    case 'isFoldable':
      return capabilities.isFoldable;
    case 'hingeAngleSensor':
      return capabilities.hingeAngleSensor;
    case 'foldingFeature':
      return capabilities.foldingFeature;
    case 'outerDisplay':
      return capabilities.outerDisplay;
    case 'sceneAccessory':
      return capabilities.sceneAccessory;
    case 'rearDisplayTransfer':
      return capabilities.rearDisplayTransfer;
    case 'dualConcurrent':
      return capabilities.dualConcurrent;
    default:
      return capabilities.raw[key] ?? false;
  }
}
