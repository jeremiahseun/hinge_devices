import { HingeAngleRange, HingeResolution } from './hinge';

/**
 * A per-device correction applied to raw hinge readings.
 *
 * Vendors disagree about hinge convention: most report `0` closed to `180`
 * flat, some report a `0`-`360` sweep, and at least one inverts the scale.
 * Corrections live in data rather than in code because they change faster
 * than this package's release cadence.
 */
export interface HingeQuirk {
  readonly range: HingeAngleRange;
  /** Whether the device reports `180` closed and `0` flat. */
  readonly inverted: boolean;
  /** A constant added to the raw reading before normalisation. */
  readonly offset: number;
  /** Whether the sensor sweeps or only reports at fixed positions. */
  readonly resolution: HingeResolution;
  /** The fixed positions a detent-reporting device produces. */
  readonly detentValues: readonly number[];
}

/**
 * The assumed behaviour when a device is not in the quirks table.
 *
 * Resolution is `unknown` rather than `continuous` on purpose: assuming a
 * smooth sweep and being wrong produces an effect that visibly snaps, which
 * is worse than not offering the effect.
 */
export const ASSUMED_QUIRK: HingeQuirk = Object.freeze({
  range: HingeAngleRange.ZeroTo180,
  inverted: false,
  offset: 0,
  resolution: HingeResolution.Unknown,
  detentValues: Object.freeze([]),
});

/**
 * Quirks shipped with the package, measured on real hardware.
 *
 * Keyed by `manufacturer/model`, lowercased. See `doc/devices.md` for how
 * each entry was obtained.
 */
const SHIPPED: Readonly<Record<string, HingeQuirk>> = Object.freeze({
  // Galaxy Z Flip 5. Measured 2026-09-14: the sensor reports exactly three
  // values across the device's whole range, however slowly it is folded.
  // Continuous angle-driven effects are not buildable here.
  'samsung/sm-f731n': Object.freeze({
    range: HingeAngleRange.ZeroTo180,
    inverted: false,
    offset: 0,
    resolution: HingeResolution.Detents,
    detentValues: Object.freeze([0, 90, 180]),
  }),
});

const registered: Record<string, HingeQuirk> = {};

/**
 * Registers or replaces a quirk for a device key.
 *
 * The key is `manufacturer/model`, lowercased, e.g. `samsung/sm-f731n`.
 * A manufacturer-wide wildcard is `samsung/*`.
 */
export function registerQuirk(deviceKey: string, quirk: HingeQuirk): void {
  registered[deviceKey.toLowerCase()] = quirk;
}

/** Removes every runtime registration. Test-only. */
export function resetQuirks(): void {
  for (const key of Object.keys(registered)) delete registered[key];
}

/**
 * Looks up a device, falling back to a manufacturer-wide entry, then to the
 * shipped table, then to {@link ASSUMED_QUIRK}.
 *
 * Runtime registrations win over shipped entries, so an app can correct a bad
 * entry without waiting for a release.
 */
export function lookupQuirk(
  manufacturer: string | null | undefined,
  model: string | null | undefined,
): HingeQuirk {
  if (manufacturer == null) return ASSUMED_QUIRK;
  const make = manufacturer.toLowerCase();
  const key = `${make}/${(model ?? '').toLowerCase()}`;
  return (
    registered[key] ??
    registered[`${make}/*`] ??
    SHIPPED[key] ??
    SHIPPED[`${make}/*`] ??
    ASSUMED_QUIRK
  );
}

/**
 * Normalises a raw reading to `0` closed, `180` flat.
 *
 * Returns `null` for a `null` input so a missing sensor never becomes a
 * misleading `0`.
 */
export function normalizeAngle(
  raw: number | null | undefined,
  quirk: HingeQuirk,
): number | null {
  if (raw == null) return null;
  let value = raw + quirk.offset;

  if (quirk.range === HingeAngleRange.ZeroTo360 && value > 180) {
    // Past 180 the device is folding back on itself; mirror it so the
    // canonical scale stays monotonic from closed to flat.
    value = 360 - value;
  }

  if (quirk.inverted) value = 180 - value;
  return Math.min(180, Math.max(0, value));
}
