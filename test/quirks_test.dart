import 'package:flutter_test/flutter_test.dart';
import 'package:hinge_devices/hinge_devices.dart';

void main() {
  setUp(FoldableQuirks.reset);

  group('normalisation', () {
    test('passes through a standard 0-180 device', () {
      const n = HingeNormalizer(HingeQuirk(range: HingeAngleRange.zeroTo180));
      expect(n.normalize(90), 90);
      expect(n.normalize(0), 0);
      expect(n.normalize(180), 180);
    });

    test('null in, null out — a missing sensor never becomes zero', () {
      const n = HingeNormalizer(HingeQuirk.assumed);
      expect(n.normalize(null), isNull);
    });

    test('mirrors a 0-360 device past the flat point', () {
      const n = HingeNormalizer(HingeQuirk(range: HingeAngleRange.zeroTo360));
      expect(n.normalize(180), 180);
      expect(n.normalize(270), 90);
      expect(n.normalize(360), 0);
    });

    test('inverts a device that reports 180 closed', () {
      const n = HingeNormalizer(
        HingeQuirk(range: HingeAngleRange.zeroTo180, inverted: true),
      );
      expect(n.normalize(0), 180);
      expect(n.normalize(180), 0);
    });

    test('applies an offset before normalising', () {
      const n = HingeNormalizer(
        HingeQuirk(range: HingeAngleRange.zeroTo180, offset: 5),
      );
      expect(n.normalize(85), 90);
    });

    test('clamps out-of-range readings', () {
      const n = HingeNormalizer(HingeQuirk.assumed);
      expect(n.normalize(-10), 0);
      expect(n.normalize(200), 180);
    });
  });

  group('lookup', () {
    test('falls back to the assumed convention for unknown devices', () {
      expect(
        FoldableQuirks.lookup('nothing', 'phone-3').range,
        HingeAngleRange.zeroTo180,
      );
    });

    test('matches an exact device key, case-insensitively', () {
      FoldableQuirks.register(
        'weirdcorp/wc-1',
        const HingeQuirk(range: HingeAngleRange.zeroTo360),
      );
      expect(
        FoldableQuirks.lookup('WeirdCorp', 'WC-1').range,
        HingeAngleRange.zeroTo360,
      );
    });

    test('falls back to a manufacturer-wide wildcard', () {
      FoldableQuirks.register(
        'weirdcorp/*',
        const HingeQuirk(range: HingeAngleRange.zeroTo180, inverted: true),
      );
      expect(FoldableQuirks.lookup('weirdcorp', 'wc-99').inverted, isTrue);
    });

    test('an exact entry beats the wildcard', () {
      FoldableQuirks.register(
        'weirdcorp/*',
        const HingeQuirk(range: HingeAngleRange.zeroTo180, inverted: true),
      );
      FoldableQuirks.register(
        'weirdcorp/wc-1',
        const HingeQuirk(range: HingeAngleRange.zeroTo180),
      );
      expect(FoldableQuirks.lookup('weirdcorp', 'wc-1').inverted, isFalse);
    });

    test('a null manufacturer is safe', () {
      expect(
          FoldableQuirks.lookup(null, null).range, HingeAngleRange.zeroTo180);
    });

    test('shipped entries are found without registration', () {
      // Measured on hardware: the Z Flip 5 reports exactly three values.
      final quirk = FoldableQuirks.lookup('samsung', 'SM-F731N');
      expect(quirk.resolution, HingeResolution.detents);
      expect(quirk.detentValues, <double>[0, 90, 180]);
    });

    test('a runtime registration overrides a shipped entry', () {
      // An app must be able to correct a bad entry without waiting for us.
      FoldableQuirks.register(
        'samsung/sm-f731n',
        const HingeQuirk(
          range: HingeAngleRange.zeroTo180,
          resolution: HingeResolution.continuous,
        ),
      );
      expect(
        FoldableQuirks.lookup('samsung', 'SM-F731N').resolution,
        HingeResolution.continuous,
      );
    });

    test('an unknown device does not claim to be continuous', () {
      // Assuming a smooth sweep and being wrong produces an effect that
      // visibly snaps, which is worse than not offering the effect.
      expect(
        FoldableQuirks.lookup('nothing', 'phone-3').resolution,
        HingeResolution.unknown,
      );
    });
  });

  group('resolution guides effect decisions', () {
    test('only a continuous hinge supports continuous effects', () {
      const continuous = Hinge(resolution: HingeResolution.continuous);
      const detents = Hinge(resolution: HingeResolution.detents);
      const unknown = Hinge();

      expect(continuous.supportsContinuousEffects, isTrue);
      expect(detents.supportsContinuousEffects, isFalse);
      expect(
        unknown.supportsContinuousEffects,
        isFalse,
        reason: 'unknown must not be optimistic',
      );
    });
  });
}
