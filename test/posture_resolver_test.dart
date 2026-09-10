import 'package:flutter/painting.dart' show Axis;
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_runtime/foldable_runtime.dart';

void main() {
  const resolver = PostureResolver();

  group('folding feature drives posture', () {
    test('flat feature resolves to flat', () {
      expect(
        resolver.resolve(featureState: FoldingFeatureState.flat, angle: 179),
        FoldPosture.flat,
      );
    });

    test('horizontal fold resolves to tabletop', () {
      expect(
        resolver.resolve(
          featureState: FoldingFeatureState.halfOpened,
          featureOrientation: Axis.horizontal,
          angle: 95,
        ),
        FoldPosture.tabletop,
      );
    });

    test('vertical fold resolves to book', () {
      expect(
        resolver.resolve(
          featureState: FoldingFeatureState.halfOpened,
          featureOrientation: Axis.vertical,
          angle: 95,
        ),
        FoldPosture.book,
      );
    });

    test('half opened without orientation stays unrefined', () {
      expect(
        resolver.resolve(featureState: FoldingFeatureState.halfOpened),
        FoldPosture.halfOpened,
      );
    });

    test('feature wins over an angle that disagrees', () {
      // A device reporting FLAT at 120 degrees is trusted: the folding feature
      // is the layout signal, angle is not.
      expect(
        resolver.resolve(featureState: FoldingFeatureState.flat, angle: 120),
        FoldPosture.flat,
      );
    });
  });

  group('closed is angle-only', () {
    test('closed below threshold', () {
      expect(resolver.resolve(angle: 5), FoldPosture.closed);
    });

    test('flipClosed when an outer display exists', () {
      expect(
        resolver.resolve(angle: 5, hasOuterDisplay: true),
        FoldPosture.flipClosed,
      );
    });

    test('closed wins even when a feature is reported', () {
      expect(
        resolver.resolve(angle: 2, featureState: FoldingFeatureState.halfOpened),
        FoldPosture.closed,
      );
    });
  });

  group('angle-only fallback', () {
    test('flat above threshold', () {
      expect(resolver.resolve(angle: 178), FoldPosture.flat);
    });

    test('half opened in between', () {
      expect(resolver.resolve(angle: 90), FoldPosture.halfOpened);
    });

    test('no signals at all is unknown, never a default posture', () {
      expect(resolver.resolve(), FoldPosture.unknown);
    });
  });

  test('thresholds are configurable', () {
    const strict = PostureResolver(
      thresholds: PostureThresholds(closedAtOrBelow: 30, flatAtOrAbove: 150),
    );
    expect(strict.resolve(angle: 25), FoldPosture.closed);
    expect(strict.resolve(angle: 155), FoldPosture.flat);
    expect(const PostureResolver().resolve(angle: 25), FoldPosture.halfOpened);
  });

  group('hinge status', () {
    test('mirrors thresholds', () {
      expect(resolver.statusFor(0), HingeStatus.closed);
      expect(resolver.statusFor(90), HingeStatus.partiallyOpen);
      expect(resolver.statusFor(180), HingeStatus.fullyOpen);
    });

    test('null angle is unknown, not closed', () {
      expect(resolver.statusFor(null), HingeStatus.unknown);
    });
  });

  group('posture hierarchy', () {
    test('refinements report as half opened', () {
      expect(FoldPosture.tabletop.isHalfOpened, isTrue);
      expect(FoldPosture.book.isHalfOpened, isTrue);
      expect(FoldPosture.halfOpened.isHalfOpened, isTrue);
      expect(FoldPosture.flat.isHalfOpened, isFalse);
    });

    test('flipClosed reports as closed', () {
      expect(FoldPosture.flipClosed.isClosed, isTrue);
      expect(FoldPosture.closed.isClosed, isTrue);
      expect(FoldPosture.tabletop.isClosed, isFalse);
    });
  });
}
