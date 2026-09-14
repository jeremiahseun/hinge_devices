// Checks an Android manifest for the configuration foldable app continuity
// needs.
//
// Shipped as an executable of the package, so apps that depend on
// foldable_runtime can lint their own manifest:
//
//   dart run foldable_runtime:check_manifest
//   dart run foldable_runtime:check_manifest path/to/AndroidManifest.xml
//
// Continuity is configuration, not an API — see doc/continuity.md. This is a
// lint, not a guarantee: it reads the manifest as text and reports what is
// missing.
import 'dart:io';

const _requiredConfigChanges = <String>[
  'screenSize',
  'smallestScreenSize',
  'screenLayout',
  'density',
];

void main(List<String> args) {
  final path =
      args.isEmpty ? 'android/app/src/main/AndroidManifest.xml' : args.first;
  final file = File(path);

  if (!file.existsSync()) {
    stderr.writeln('No manifest at $path');
    exitCode = 2;
    return;
  }

  final manifest = file.readAsStringSync();
  final findings = <String>[];

  if (!manifest.contains('android:resizeableActivity="true"')) {
    findings.add(
      'android:resizeableActivity="true" is not set on <application>.\n'
      '  Without it the system letterboxes your app instead of moving it to\n'
      '  the other display, and continuity never happens.',
    );
  }

  final configChanges =
      RegExp('android:configChanges="([^"]*)"').firstMatch(manifest)?.group(1);

  if (configChanges == null) {
    findings.add(
      'No android:configChanges on any <activity>.\n'
      '  Your Activity will be destroyed and recreated on every fold, losing\n'
      '  Dart state, scroll position and in-flight work.',
    );
  } else {
    final missing = _requiredConfigChanges
        .where((flag) => !configChanges.contains(flag))
        .toList();
    if (missing.isNotEmpty) {
      findings.add(
        'android:configChanges is missing: ${missing.join(', ')}.\n'
        '  Each missing flag is a fold that destroys your Activity.',
      );
    }
  }

  if (!manifest.contains('android:launchMode="singleTop"') &&
      !manifest.contains('android:launchMode="singleTask"')) {
    findings.add(
      'No singleTop/singleTask launch mode.\n'
      '  A second instance of your Activity may be created on the new display.',
    );
  }

  if (findings.isEmpty) {
    stdout.writeln('$path is configured for foldable continuity.');
    return;
  }

  stdout.writeln('$path — ${findings.length} finding(s):\n');
  for (final finding in findings) {
    stdout.writeln('• $finding\n');
  }
  stdout.writeln(
    'See https://github.com/jeremiahseun/hinge_devices/blob/main/doc/continuity.md',
  );
  exitCode = 1;
}
