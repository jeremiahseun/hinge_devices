import { HingeAngleRange, HingeResolution } from '../src/model/hinge';
import {
  ASSUMED_QUIRK,
  lookupQuirk,
  normalizeAngle,
  registerQuirk,
  resetQuirks,
} from '../src/model/quirks';

afterEach(resetQuirks);

describe('normalisation', () => {
  it('passes through a standard 0-180 device', () => {
    expect(normalizeAngle(90, ASSUMED_QUIRK)).toBe(90);
    expect(normalizeAngle(0, ASSUMED_QUIRK)).toBe(0);
    expect(normalizeAngle(180, ASSUMED_QUIRK)).toBe(180);
  });

  it('null in, null out — a missing sensor never becomes zero', () => {
    expect(normalizeAngle(null, ASSUMED_QUIRK)).toBeNull();
    expect(normalizeAngle(undefined, ASSUMED_QUIRK)).toBeNull();
  });

  it('mirrors a 0-360 device past the flat point', () => {
    const quirk = { ...ASSUMED_QUIRK, range: HingeAngleRange.ZeroTo360 };
    expect(normalizeAngle(180, quirk)).toBe(180);
    expect(normalizeAngle(270, quirk)).toBe(90);
    expect(normalizeAngle(360, quirk)).toBe(0);
  });

  it('inverts a device that reports 180 closed', () => {
    const quirk = { ...ASSUMED_QUIRK, inverted: true };
    expect(normalizeAngle(0, quirk)).toBe(180);
    expect(normalizeAngle(180, quirk)).toBe(0);
  });

  it('applies an offset before normalising', () => {
    expect(normalizeAngle(85, { ...ASSUMED_QUIRK, offset: 5 })).toBe(90);
  });

  it('clamps out-of-range readings', () => {
    expect(normalizeAngle(-10, ASSUMED_QUIRK)).toBe(0);
    expect(normalizeAngle(200, ASSUMED_QUIRK)).toBe(180);
  });
});

describe('lookup', () => {
  it('falls back to the assumed convention for unknown devices', () => {
    expect(lookupQuirk('nothing', 'phone-3').range).toBe(
      HingeAngleRange.ZeroTo180,
    );
  });

  it('an unknown device does not claim to be continuous', () => {
    // Assuming a smooth sweep and being wrong produces an effect that
    // visibly snaps, which is worse than not offering the effect.
    expect(lookupQuirk('nothing', 'phone-3').resolution).toBe(
      HingeResolution.Unknown,
    );
  });

  it('finds shipped entries without registration', () => {
    // Measured on hardware: the Z Flip 5 reports exactly three values.
    const quirk = lookupQuirk('samsung', 'SM-F731N');
    expect(quirk.resolution).toBe(HingeResolution.Detents);
    expect(quirk.detentValues).toEqual([0, 90, 180]);
  });

  it('matches case-insensitively', () => {
    expect(lookupQuirk('SAMSUNG', 'sm-f731n').resolution).toBe(
      HingeResolution.Detents,
    );
  });

  it('lets a runtime registration override a shipped entry', () => {
    // An app must be able to correct a bad entry without waiting for us.
    registerQuirk('samsung/sm-f731n', {
      ...ASSUMED_QUIRK,
      resolution: HingeResolution.Continuous,
    });
    expect(lookupQuirk('samsung', 'SM-F731N').resolution).toBe(
      HingeResolution.Continuous,
    );
  });

  it('falls back to a manufacturer-wide wildcard', () => {
    registerQuirk('weirdcorp/*', { ...ASSUMED_QUIRK, inverted: true });
    expect(lookupQuirk('weirdcorp', 'wc-99').inverted).toBe(true);
  });

  it('is safe with a null manufacturer', () => {
    expect(lookupQuirk(null, null)).toBe(ASSUMED_QUIRK);
  });
});
