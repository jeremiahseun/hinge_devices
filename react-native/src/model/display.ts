/** Which physical display the app is currently rendering on. */
export const ActiveDisplay = {
  /** The large, inner display of a book-style foldable. */
  Inner: 'inner',
  /** The outer display used while the device is folded. */
  Outer: 'outer',
  /** A small cover display, e.g. a Flip-class Flex Window. */
  Cover: 'cover',
  /** A rear-facing display, reachable via display transfer. */
  Rear: 'rear',
  /** Not reported by this platform. */
  Unknown: 'unknown',
} as const;
export type ActiveDisplay = (typeof ActiveDisplay)[keyof typeof ActiveDisplay];

/** What a display feature does to the pixels underneath it. */
export const FeatureOcclusion = {
  None: 'none',
  Full: 'full',
  Unknown: 'unknown',
} as const;
export type FeatureOcclusion =
  (typeof FeatureOcclusion)[keyof typeof FeatureOcclusion];

/** A rectangle in density-independent pixels, relative to the app window. */
export interface Rect {
  readonly left: number;
  readonly top: number;
  readonly right: number;
  readonly bottom: number;
}

/** A physical discontinuity in the display — a hinge or a fold. */
export interface FoldableDisplayFeature {
  readonly bounds: Rect;
  /**
   * Whether the feature splits the window into two logical areas that should
   * be laid out independently.
   */
  readonly isSeparating: boolean;
  readonly occlusion: FeatureOcclusion;
  readonly orientation: 'horizontal' | 'vertical' | null;
}

/** Information about the display the app currently occupies. */
export interface DisplayInfo {
  readonly active: ActiveDisplay;
  readonly features: readonly FoldableDisplayFeature[];
  readonly width: number | null;
  readonly height: number | null;
}

/** An empty description, for devices that report nothing. */
export const EMPTY_DISPLAY: DisplayInfo = Object.freeze({
  active: ActiveDisplay.Unknown,
  features: Object.freeze([]),
  width: null,
  height: null,
});

/** True when any feature splits the window into independent panes. */
export function isSeparating(display: DisplayInfo): boolean {
  return display.features.some((feature) => feature.isSeparating);
}
