import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as mobile;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Phones use the platform SQLite plugin; desktops use SQLite through FFI.
Future<(DatabaseFactory, String)> openFactory(String name) async {
  if (Platform.isAndroid || Platform.isIOS) {
    final dir = await mobile.getDatabasesPath();
    return (mobile.databaseFactory, p.join(dir, name));
  }
  sqfliteFfiInit();
  final dir = await getApplicationSupportDirectory();
  await dir.create(recursive: true);
  return (databaseFactoryFfi, p.join(dir.path, name));
}
