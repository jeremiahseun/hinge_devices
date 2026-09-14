import 'dart:convert';
import 'dart:io';

import 'package:flutter/painting.dart' show Axis;
import 'package:flutter_test/flutter_test.dart';
import 'package:hinge_devices/hinge_devices.dart';

/// Runs the shared conformance vectors against the Dart resolver.
///
/// The React Native package runs the same file. That is what stops the two
/// implementations drifting: a posture rule changed in one language and not
/// the other fails here or there, rather than silently shipping two products
/// that disagree about what `tabletop` means.
void main() {
  // The vectors live at the repo root, shared with the React Native package.
  // Tests run from the Flutter package directory, so look one level up first
  // and fall back for anyone running from the repo root.
  final file = [
    File('../spec/posture_vectors.json'),
    File('spec/posture_vectors.json'),
  ].firstWhere(
    (candidate) => candidate.existsSync(),
    orElse: () => File('../spec/posture_vectors.json'),
  );

  test('the shared vector file exists and is well formed', () {
    expect(
      file.existsSync(),
      isTrue,
      reason: 'spec/posture_vectors.json is the cross-language contract',
    );
  });

  final spec = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  final thresholds = spec['thresholds']! as Map<String, Object?>;
  final resolver = PostureResolver(
    thresholds: PostureThresholds(
      closedAtOrBelow: (thresholds['closedAtOrBelow']! as num).toDouble(),
      flatAtOrAbove: (thresholds['flatAtOrAbove']! as num).toDouble(),
    ),
  );

  final cases = spec['cases']! as List<Object?>;

  test('every case is named and has an expectation', () {
    for (final raw in cases) {
      final c = raw! as Map<String, Object?>;
      expect(c['name'], isA<String>());
      expect(c['expect'], isA<Map<String, Object?>>());
    }
  });

  for (final raw in cases) {
    final testCase = raw! as Map<String, Object?>;
    final name = testCase['name']! as String;
    final given = (testCase['given'] as Map<String, Object?>?) ??
        const <String, Object?>{};
    final expected = testCase['expect']! as Map<String, Object?>;

    test('conformance: $name', () {
      final angle = (given['angle'] as num?)?.toDouble();

      final posture = resolver.resolve(
        featureState: switch (given['featureState'] as String?) {
          'flat' => FoldingFeatureState.flat,
          'halfOpened' => FoldingFeatureState.halfOpened,
          _ => null,
        },
        featureOrientation: switch (given['featureOrientation'] as String?) {
          'horizontal' => Axis.horizontal,
          'vertical' => Axis.vertical,
          _ => null,
        },
        angle: angle,
        hasOuterDisplay: given['hasOuterDisplay'] as bool? ?? false,
      );

      expect(posture.name, expected['posture'], reason: 'posture');
      expect(
        resolver.statusFor(angle).name,
        expected['status'],
        reason: 'hinge status',
      );
      expect(posture.coarse.name, expected['coarse'], reason: 'coarse posture');
    });
  }
}
