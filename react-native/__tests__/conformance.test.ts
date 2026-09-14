import { readFileSync } from 'fs';
import { join } from 'path';

import { coarsePosture } from '../src/model/posture';
import {
  FoldingFeatureState,
  hingeStatusFor,
  resolvePosture,
} from '../src/model/resolver';
import type { FoldAxis } from '../src/model/hinge';

/**
 * Runs the shared conformance vectors against the TypeScript resolver.
 *
 * The Dart package runs the same file. That is what stops the two
 * implementations drifting: a posture rule changed in one language and not
 * the other fails here or there, rather than silently shipping two products
 * that disagree about what `tabletop` means.
 */
interface VectorCase {
  name: string;
  given?: {
    featureState?: string | null;
    featureOrientation?: string | null;
    angle?: number | null;
    hasOuterDisplay?: boolean;
  };
  expect: { posture: string; status: string; coarse: string };
}

interface VectorFile {
  specVersion: number;
  thresholds: { closedAtOrBelow: number; flatAtOrAbove: number };
  cases: VectorCase[];
}

const spec: VectorFile = JSON.parse(
  readFileSync(join(__dirname, '..', '..', 'spec', 'posture_vectors.json'), 'utf8'),
);

describe('shared posture vectors', () => {
  it('loads the cross-language contract', () => {
    expect(spec.cases.length).toBeGreaterThan(0);
    expect(spec.specVersion).toBe(1);
  });

  it.each(spec.cases.map((c) => [c.name, c] as const))(
    'conformance: %s',
    (_name, testCase) => {
      const given = testCase.given ?? {};
      const angle = given.angle ?? null;

      const posture = resolvePosture(
        {
          featureState:
            given.featureState === 'flat' || given.featureState === 'halfOpened'
              ? (given.featureState as FoldingFeatureState)
              : null,
          featureOrientation:
            given.featureOrientation === 'horizontal' ||
            given.featureOrientation === 'vertical'
              ? (given.featureOrientation as FoldAxis)
              : null,
          angle,
          hasOuterDisplay: given.hasOuterDisplay ?? false,
        },
        spec.thresholds,
      );

      expect(posture).toBe(testCase.expect.posture);
      expect(hingeStatusFor(angle, spec.thresholds)).toBe(
        testCase.expect.status,
      );
      expect(coarsePosture(posture)).toBe(testCase.expect.coarse);
    },
  );
});
