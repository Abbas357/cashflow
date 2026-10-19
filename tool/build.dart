import 'dart:io';

/// Builds an APK to copy to a phone and install.
///
///   dart tool/build.dart       the signed production APK, "Cash Flow"
///   dart tool/build.dart dev   the dev APK, "Cash Flow Dev", installed
///                              beside the production app with its own data
///
/// Named for its version in `build/app/outputs/flutter-apk/`:
/// `CashFlow-v<version>.apk` or `CashFlow-Dev-v<version>.apk`. Raise
/// `version:` in pubspec.yaml before a release: the number after the + has
/// to go up for phones to take the APK as an update.
///
/// Builds from the local Gradle cache (the same Gradle, Android plugin and
/// Kotlin versions as the HRM app), so nothing needs downloading.
Future<void> main(List<String> args) async {
  final dev = args.contains('dev');
  if (args.any((a) => a != 'dev')) {
    stderr.writeln('Usage: dart tool/build.dart [dev]');
    exit(64);
  }

  final version = RegExp(
    r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)',
    multiLine: true,
  ).firstMatch(File('pubspec.yaml').readAsStringSync());
  if (version == null) {
    stderr.writeln('No version like 1.2.1+4 found in pubspec.yaml.');
    exit(1);
  }
  if (!dev && !File('android/key.properties').existsSync()) {
    stderr.writeln(
      'Missing android/key.properties: restore it and the keystore from your backup.',
    );
    exit(1);
  }

  final flutter = await Process.start(
    'flutter',
    [
      'build',
      'apk',
      dev ? '--debug' : '--release',
      '--android-skip-build-dependency-validation',
    ],
    mode: ProcessStartMode.inheritStdio,
    runInShell: true,
  );
  final code = await flutter.exitCode;
  if (code != 0) exit(code);

  const outputs = 'build/app/outputs/flutter-apk';
  final apk = File(
    '$outputs/app-${dev ? 'debug' : 'release'}.apk',
  ).copySync('$outputs/CashFlow${dev ? '-Dev' : ''}-v${version[1]}.apk');
  final megabytes = (apk.lengthSync() / (1024 * 1024)).toStringAsFixed(1);

  stdout.writeln(
    '\n${dev ? 'Dev build' : 'Version'} ${version[1]} (build ${version[2]}), '
    '$megabytes MB:\n${apk.absolute.path}',
  );
}
