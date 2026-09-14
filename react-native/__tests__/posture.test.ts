import {
  CoarsePosture,
  FoldPosture,
  coarsePosture,
  isClosed,
  isHalfOpened,
} from '../src/model/posture';
import { RIGID_DEVICE, sameLayout } from '../src/model/state';
import { HingeResolution, NO_HINGE, supportsContinuousEffects } from '../src/model/hinge';

describe('posture hierarchy', () => {
  it('reports refinements as half opened', () => {
    expect(isHalfOpened(FoldPosture.Tabletop)).toBe(true);
    expect(isHalfOpened(FoldPosture.Book)).toBe(true);
    expect(isHalfOpened(FoldPosture.HalfOpened)).toBe(true);
    expect(isHalfOpened(FoldPosture.Flat)).toBe(false);
  });

  it('reports flipClosed as closed', () => {
    expect(isClosed(FoldPosture.FlipClosed)).toBe(true);
    expect(isClosed(FoldPosture.Closed)).toBe(true);
    expect(isClosed(FoldPosture.Tabletop)).toBe(false);
  });

  // Handling 'closed' alone drops 'flipClosed', which put a shut Flip on its
  // opened layout. The coarse enum exists so that cannot happen.
  it('collapses every closed posture to CoarsePosture.Closed', () => {
    expect(coarsePosture(FoldPosture.Closed)).toBe(CoarsePosture.Closed);
    expect(coarsePosture(FoldPosture.FlipClosed)).toBe(CoarsePosture.Closed);
  });

  it('maps unknown to open so an unreported device renders normally', () => {
    expect(coarsePosture(FoldPosture.Unknown)).toBe(CoarsePosture.Open);
  });

  it('maps every posture to a coarse state', () => {
    for (const posture of Object.values(FoldPosture)) {
      expect(coarsePosture(posture)).toBeDefined();
    }
  });
});

describe('layout equality', () => {
  it('ignores an angle wiggle', () => {
    const base = { ...RIGID_DEVICE, posture: FoldPosture.Tabletop };
    const wiggled = {
      ...base,
      hinge: { ...NO_HINGE, angle: 91 },
      timestamp: 1234,
    };
    expect(sameLayout(base, wiggled)).toBe(true);
  });

  it('notices a posture change', () => {
    const a = { ...RIGID_DEVICE, posture: FoldPosture.Tabletop };
    const b = { ...RIGID_DEVICE, posture: FoldPosture.Flat };
    expect(sameLayout(a, b)).toBe(false);
  });
});

describe('hinge resolution', () => {
  it('only a continuous hinge supports continuous effects', () => {
    expect(
      supportsContinuousEffects({
        ...NO_HINGE,
        resolution: HingeResolution.Continuous,
      }),
    ).toBe(true);
    expect(
      supportsContinuousEffects({
        ...NO_HINGE,
        resolution: HingeResolution.Detents,
      }),
    ).toBe(false);
    expect(supportsContinuousEffects(NO_HINGE)).toBe(false);
  });
});
