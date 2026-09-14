// Keeps every package manifest in step with spec/version.json.
//
//   dart run tool/check_versions.dart                      # verify (CI)
//   dart run tool/check_versions.dart --set-minor 4        # shared bump
//   dart run tool/check_versions.dart --set-patch hinge_devices 1
//
// Major and minor are shared across every package so that one version number
// describes one API on every framework. Patch is per package. See
// VERSIONING.md for why.
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final spec = _Spec.load();

  if (args.isEmpty) {
    exitCode = spec.verify() ? 0 : 1;
    return;
  }

  switch (args.first) {
    case '--set-minor' when args.length == 2:
      spec.setMinor(int.parse(args[1]));
    case '--set-major' when args.length == 2:
      spec.setMajor(int.parse(args[1]));
    case '--set-patch' when args.length == 3:
      spec.setPatch(args[1], int.parse(args[2]));
    default:
      stderr.writeln('Usage:\n'
          '  dart run tool/check_versions.dart\n'
          '  dart run tool/check_versions.dart --set-major <n>\n'
          '  dart run tool/check_versions.dart --set-minor <n>\n'
          '  dart run tool/check_versions.dart --set-patch <package> <n>');
      exitCode = 2;
  }
}

class _Spec {
  _Spec(this.file, this.json);

  static const _path = 'spec/version.json';

  final File file;
  final Map<String, Object?> json;

  static _Spec load() {
    final file = File(_path);
    if (!file.existsSync()) {
      stderr.writeln('Missing $_path — it is the source of truth.');
      exit(2);
    }
    return _Spec(
      file,
      jsonDecode(file.readAsStringSync()) as Map<String, Object?>,
    );
  }

  int get major => json['major']! as int;
  int get minor => json['minor']! as int;

  Map<String, Object?> get packages =>
      json['packages']! as Map<String, Object?>;

  bool _isPending(String name) =>
      (packages[name]! as Map<String, Object?>)['pending'] == true;

  String versionOf(String package) {
    final entry = packages[package]! as Map<String, Object?>;
    return '$major.$minor.${entry['patch']}';
  }

  /// Checks every manifest against the spec. Prints every problem rather than
  /// stopping at the first, so one CI run tells you everything to fix.
  bool verify() {
    final problems = <String>[];
    final pendingNotes = <String>[];

    for (final name in packages.keys) {
      final entry = packages[name]! as Map<String, Object?>;
      final manifestPath = entry['manifest']! as String;
      final manifest = File(manifestPath);

      // A package can be registered before it exists, so the version
      // contract is visible from the day it is agreed rather than the day the
      // code lands. Remove "pending" to start enforcing it.
      final pending = entry['pending'] == true;

      if (!manifest.existsSync()) {
        if (pending) {
          pendingNotes.add('$name (${entry['package']}) reserved at '
              '${versionOf(name)}, not built yet');
          continue;
        }
        problems.add('$name: no manifest at $manifestPath');
        continue;
      }

      if (pending) {
        problems.add(
          '$name: $manifestPath now exists — remove "pending" from '
          'spec/version.json so its version is enforced.',
        );
        continue;
      }

      final expected = versionOf(name);
      final actual = _readVersion(manifest, entry['ecosystem']! as String);

      if (actual == null) {
        problems.add('$name: could not read a version from $manifestPath');
      } else if (actual != expected) {
        problems.add(
          '$name: $manifestPath says $actual, spec says $expected.\n'
          '    Major and minor are shared across packages — edit '
          'spec/version.json, not the manifest.',
        );
      }
    }

    if (problems.isEmpty) {
      final summary = packages.keys
          .where((name) => !_isPending(name))
          .map((name) => '$name ${versionOf(name)}')
          .join(', ');
      stdout.writeln('Versions are in step: $summary');
      for (final note in pendingNotes) {
        stdout.writeln('  (pending) $note');
      }
      return true;
    }

    stdout.writeln('Version check failed:\n');
    for (final problem in problems) {
      stdout.writeln('  • $problem\n');
    }
    stdout.writeln('See VERSIONING.md.');
    return false;
  }

  String? _readVersion(File manifest, String ecosystem) {
    final text = manifest.readAsStringSync();
    final pattern = ecosystem == 'pub.dev'
        ? RegExp(r'^version:\s*(\S+)\s*$', multiLine: true)
        : RegExp(r'"version"\s*:\s*"([^"]+)"');
    return pattern.firstMatch(text)?.group(1);
  }

  void setMajor(int value) {
    json['major'] = value;
    json['minor'] = 0;
    // A shared bump resets every patch: the packages are realigned.
    for (final entry in packages.values) {
      (entry! as Map<String, Object?>)['patch'] = 0;
    }
    _write('major $value');
  }

  void setMinor(int value) {
    json['minor'] = value;
    for (final entry in packages.values) {
      (entry! as Map<String, Object?>)['patch'] = 0;
    }
    _write('minor $value');
  }

  void setPatch(String package, int value) {
    final entry = packages[package] as Map<String, Object?>?;
    if (entry == null) {
      stderr.writeln('Unknown package "$package". '
          'Known: ${packages.keys.join(', ')}');
      exit(2);
    }
    entry['patch'] = value;
    _write('$package patch $value');
  }

  void _write(String change) {
    file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(json)}\n');

    for (final name in packages.keys) {
      final entry = packages[name]! as Map<String, Object?>;
      final manifest = File(entry['manifest']! as String);
      if (!manifest.existsSync()) {
        stdout.writeln('$name → ${versionOf(name)} (reserved, not built yet)');
        continue;
      }

      final version = versionOf(name);
      final ecosystem = entry['ecosystem']! as String;
      final text = manifest.readAsStringSync();

      manifest.writeAsStringSync(
        ecosystem == 'pub.dev'
            ? text.replaceFirst(
                RegExp(r'^version:.*$', multiLine: true),
                'version: $version',
              )
            : text.replaceFirst(
                RegExp(r'"version"\s*:\s*"[^"]+"'),
                '"version": "$version"',
              ),
      );
      stdout.writeln('$name → $version');
    }
    stdout.writeln('Set $change. Commit spec/version.json with the manifests.');
  }
}
