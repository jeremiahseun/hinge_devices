import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_runtime/foldable_runtime.dart';

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
      expect(FoldableQuirks.lookup(null, null).range, HingeAngleRange.zeroTo180);
    });
  });
}
