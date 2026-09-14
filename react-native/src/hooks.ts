import { useCallback, useEffect, useRef, useState } from 'react';

import { FoldableDevice } from './device';
import { FoldableCapabilities, NO_CAPABILITIES } from './model/capabilities';
import { CoarsePosture, FoldPosture, coarsePosture } from './model/posture';
import { FoldableState, RIGID_DEVICE, sameLayout } from './model/state';

/**
 * Subscribes to the full device state.
 *
 * Re-renders only when something layout-relevant changes. A state whose only
 * difference is a hinge-angle wiggle does not re-render — that would rebuild
 * your tree sixty times a second. Use {@link useHingeAngle} for continuous
 * values.
 */
export function useFoldableDevice(): FoldableState {
  const [state, setState] = useState<FoldableState>(
    () => FoldableDevice.currentState ?? RIGID_DEVICE,
  );
  const latest = useRef(state);

  useEffect(() => {
    return FoldableDevice.subscribe((next) => {
      if (sameLayout(latest.current, next)) return;
      latest.current = next;
      setState(next);
    });
  }, []);

  return state;
}

/** Subscribes to posture changes only. */
export function useFoldPosture(): FoldPosture {
  return useFoldableDevice().posture;
}

/**
 * Subscribes to the coarse posture — the three states most apps branch on.
 *
 * Prefer this over switching on `FoldPosture` directly: handling `'closed'`
 * alone silently drops `'flipClosed'`, which puts a Flip on its cover screen
 * into the opened layout.
 */
export function useCoarsePosture(): CoarsePosture {
  return coarsePosture(useFoldPosture());
}

/** Reads device capabilities once. `null` until they resolve. */
export function useFoldableCapabilities(): FoldableCapabilities | null {
  const [capabilities, setCapabilities] =
    useState<FoldableCapabilities | null>(null);

  useEffect(() => {
    let active = true;
    void FoldableDevice.getCapabilities().then((next) => {
      if (active) setCapabilities(next);
    });
    return () => {
      active = false;
    };
  }, []);

  return capabilities;
}

/** Options for {@link useHingeAngle}. */
export interface HingeAngleOptions {
  /**
   * Whether to raise the sensor's sampling rate while this hook is mounted.
   * Reference counted, so several components can ask independently.
   */
  readonly enabled?: boolean;
  /** Minimum interval between re-renders. One frame at 60Hz by default. */
  readonly throttleMs?: number;
  /**
   * The angle used on devices with no hinge sensor.
   *
   * Defaults to fully flat, so an effect written against this degrades to its
   * open state on ordinary phones rather than collapsing to zero.
   */
  readonly fallback?: number;
}

/**
 * Subscribes to the continuous hinge angle, for effects.
 *
 * Do not lay out with this. Angle is a continuous signal and using it to pick
 * between layouts produces thrash at the boundaries; that is what
 * {@link useCoarsePosture} is for.
 *
 * Check `capabilities` and `hinge.resolution` first — a Galaxy Z Flip 5
 * reports exactly three angles, so an effect built on a smooth sweep has
 * three states there.
 */
export function useHingeAngle(options: HingeAngleOptions = {}): number {
  const { enabled = true, throttleMs = 16, fallback = 180 } = options;

  const [angle, setAngle] = useState(fallback);
  const lastEmit = useRef(0);

  useEffect(() => {
    if (!enabled) return;
    FoldableDevice.enableAngleUpdates();
    return () => FoldableDevice.disableAngleUpdates();
  }, [enabled]);

  useEffect(() => {
    return FoldableDevice.subscribe((state) => {
      const next = state.hinge.angle;
      if (next == null) return;

      const now = Date.now();
      if (now - lastEmit.current < throttleMs) return;
      lastEmit.current = now;

      setAngle((previous) => (previous === next ? previous : next));
    });
  }, [throttleMs]);

  return angle;
}

/**
 * Forces a posture for local development.
 *
 * Returns a setter you can wire to a debug menu. Pass `null` to hand control
 * back to the platform.
 */
export function useFoldableDebugOverride(): (
  state: FoldableState | null,
) => void {
  return useCallback((state: FoldableState | null) => {
    FoldableDevice.debugOverride(state);
  }, []);
}

export { NO_CAPABILITIES };
