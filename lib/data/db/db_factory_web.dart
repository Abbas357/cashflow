import 'package:sqflite_common_ffi/sqflite_ffi.dart' show DatabaseFactory;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// The browser keeps SQLite (WASM) in IndexedDB.
Future<(DatabaseFactory, String)> openFactory(String name) async =>
    (databaseFactoryFfiWeb, name);
