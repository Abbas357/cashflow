import 'dart:io';

/// The debug build on the phone: `dart tool/dev.dart`.
///
/// Runs on the first phone adb sees, by USB or wireless debugging, unless one
/// is named (`dart tool/dev.dart R5CT51XZF3H`). It installs as "Cash Flow
/// Dev", beside the released app, with its own data. The keys are those of
/// `flutter run`: r hot reload, R hot restart, q quit.
Future<void> main(List<String> args) async {
  final device = args.isNotEmpty ? args.first : await _firstPhone();
  if (device == null) {
    stderr.writeln(
      'No phone found. Connect it by USB or wireless debugging, '
      'then check `adb devices`.',
    );
    exit(1);
  }
  stdout.writeln('Running on $device');

  final flutter = await Process.start(
    'flutter',
    [
      'run',
      '--debug',
      '-d',
      device,
      '--android-skip-build-dependency-validation',
    ],
    mode: ProcessStartMode.inheritStdio,
    runInShell: true,
  );
  exit(await flutter.exitCode);
}

/// The first device `adb devices` lists as ready, or null.
Future<String?> _firstPhone() async {
  final ProcessResult result;
  try {
    result = await Process.run('adb', ['devices'], runInShell: true);
  } on ProcessException {
    stderr.writeln('adb was not found. Add the Android SDK platform-tools folder to PATH.');
    return null;
  }

  for (final line in (result.stdout as String).split('\n').skip(1)) {
    final columns = line.trim().split(RegExp(r'\s+'));
    if (columns.length == 2 && columns[1] == 'device') return columns[0];
  }

  return null;
}
