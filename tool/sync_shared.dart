// Vendors shared/ into every package that needs it, and proves they match.
//
//   dart run tool/sync_shared.dart            # copy shared/ into each package
//   dart run tool/sync_shared.dart --check    # fail if any copy has drifted
//
// The hinge sensor, window-layout observer and display source are the same
// code on Flutter and React Native, and every bug found on real hardware so
// far has been in exactly that code. Keeping one copy means a fix lands in
// both frameworks at once.
//
// Why vendoring and not a Maven artifact: a published package must be
// self-contained — the pub.dev archive ships only its own android/ folder,
// and the npm tarball only its own. A shared Maven Central artifact is the
// textbook answer and needs a signing pipeline; this gets the same guarantee
// today, because --check runs in CI and drift fails the build.
import 'dart:io';

const _sharedRoot = 'shared/android/src/main/kotlin';

/// Where the shared Kotlin is vendored, per package.
const _targets = <String, String>{
  'flutter': 'android/src/main/kotlin',
  'react-native': 'react-native/android/src/main/kotlin',
};

const _banner = '''
// GENERATED FILE — DO NOT EDIT.
//
// Vendored from shared/android/. Edit the file there, then run:
//     dart run tool/sync_shared.dart
''';

void main(List<String> args) {
  final check = args.contains('--check');
  final shared = Directory(_sharedRoot);

  if (!shared.existsSync()) {
    stderr.writeln('Missing $_sharedRoot');
    exit(2);
  }

  final sources = shared
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.kt'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  if (sources.isEmpty) {
    stderr.writeln('No Kotlin sources under $_sharedRoot');
    exit(2);
  }

  final drifted = <String>[];
  final written = <String>[];

  for (final entry in _targets.entries) {
    for (final source in sources) {
      final relative = source.path.substring(_sharedRoot.length + 1);
      final destination = File('${entry.value}/$relative');
      final expected = _banner + source.readAsStringSync();

      if (check) {
        if (!destination.existsSync()) {
          drifted.add('${entry.key}: missing ${destination.path}');
        } else if (destination.readAsStringSync() != expected) {
          drifted.add('${entry.key}: ${destination.path} differs from shared');
        }
        continue;
      }

      destination.parent.createSync(recursive: true);
      destination.writeAsStringSync(expected);
      written.add(destination.path);
    }
  }

  if (check) {
    if (drifted.isEmpty) {
      stdout.writeln(
        'Shared Kotlin is in sync across ${_targets.length} packages '
        '(${sources.length} files each).',
      );
      return;
    }
    stdout.writeln('Shared Kotlin has drifted:\n');
    for (final problem in drifted) {
      stdout.writeln('  • $problem');
    }
    stdout.writeln(
      '\nEdit shared/android/, then run: dart run tool/sync_shared.dart',
    );
    exitCode = 1;
    return;
  }

  for (final path in written) {
    stdout.writeln('wrote $path');
  }
  stdout.writeln(
      'Synced ${sources.length} files into ${_targets.length} packages.');
}
