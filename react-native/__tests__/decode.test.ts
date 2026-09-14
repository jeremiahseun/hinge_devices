import { decodeCapabilities, decodeState } from '../src/decode';
import { ActiveDisplay } from '../src/model/display';
import { ASSUMED_QUIRK } from '../src/model/quirks';
import { FoldPosture } from '../src/model/posture';
import { NO_CAPABILITIES, capability } from '../src/model/capabilities';
import { STANDARD_THRESHOLDS } from '../src/model/resolver';

const context = {
  quirk: ASSUMED_QUIRK,
  capabilities: NO_CAPABILITIES,
  thresholds: STANDARD_THRESHOLDS,
};

describe('capability decoding', () => {
  it('keeps unknown capabilities readable', () => {
    const caps = decodeCapabilities({
      isFoldable: true,
      triFold: true,
      specVersion: 9,
      manufacturer: 'weirdcorp',
    });

    expect(caps.isFoldable).toBe(true);
    expect(caps.specVersion).toBe(9);
    expect(capability(caps, 'triFold')).toBe(true);
    expect(capability(caps, 'inventedCapability')).toBe(false);
  });

  it('ignores non-boolean values in the raw map', () => {
    const caps = decodeCapabilities({ manufacturer: 'samsung' });
    expect(caps.raw.manufacturer).toBeUndefined();
  });

  it('survives an empty reply', () => {
    expect(decodeCapabilities({}).isFoldable).toBe(false);
  });
});

describe('state decoding', () => {
  it('derives tabletop from a horizontal folding feature', () => {
    const { state } = decodeState(
      {
        featureState: 'halfOpened',
        featureOrientation: 'horizontal',
        hingeAngle: 90,
        windowWidth: 360,
        windowHeight: 880,
        features: [
          { left: 0, top: 439, right: 360, bottom: 441, isSeparating: true, occlusion: 'full' },
        ],
      },
      context,
    );

    expect(state.posture).toBe(FoldPosture.Tabletop);
    expect(state.hinge.angle).toBe(90);
    expect(state.display.features).toHaveLength(1);
    expect(state.display.features[0]?.isSeparating).toBe(true);
    expect(state.display.features[0]?.orientation).toBe('horizontal');
  });

  it('survives a payload with nothing in it', () => {
    // A platform that reports nothing must not take the stream down.
    const { state } = decodeState({}, context);
    expect(state.posture).toBe(FoldPosture.Unknown);
    expect(state.hinge.angle).toBeNull();
    expect(state.display.active).toBe(ActiveDisplay.Unknown);
  });

  it('ignores malformed feature entries rather than throwing', () => {
    const { state } = decodeState(
      { features: [null, 'nonsense', 42, {}] },
      context,
    );
    expect(state.display.features).toHaveLength(1);
  });

  it('deduces an outer display from a shut device that is still drawing', () => {
    // Android exposes no public API for "am I on the cover screen", and on
    // Flip-class hardware both panels are the same logical display. But a
    // device that is shut and still drawing must be drawing somewhere.
    const { state, learnedOuterDisplay } = decodeState(
      { hingeAngle: 0, windowWidth: 427, windowHeight: 411 },
      context,
    );

    expect(learnedOuterDisplay).toBe(true);
    expect(state.capabilities.outerDisplay).toBe(true);
    expect(capability(state.capabilities, 'outerDisplay')).toBe(true);
    expect(state.posture).toBe(FoldPosture.FlipClosed);
  });

  it('does not deduce an outer display from an open device', () => {
    const { learnedOuterDisplay } = decodeState({ hingeAngle: 180 }, context);
    expect(learnedOuterDisplay).toBe(false);
  });

  it('a closed angle outranks a reported folding feature', () => {
    // Measured on a Z Flip 5 running on its Flex Window.
    const { state } = decodeState(
      { featureState: 'flat', hingeAngle: 0 },
      context,
    );
    expect(state.posture).toBe(FoldPosture.FlipClosed);
  });

  it('a cleared reading never resolves to closed', () => {
    // The sensor clears its value when unregistered, so a stale reading
    // arrives as null rather than as zero.
    const { state } = decodeState({ featureState: 'flat' }, context);
    expect(state.posture).toBe(FoldPosture.Flat);
  });
});
