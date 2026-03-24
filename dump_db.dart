import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'dart:io';

void main() async {
  sqfliteFfiInit();
  final databaseFactory = databaseFactoryFfi;
  final dbPath = join('c:/Users/Chokowa/Desktop/myTools/SubStop', '.dart_tool', 'sqflite_common_ffi', 'databases', 'substop_real.db');
  // 実際にはスマホ上にあるので取れない！
}
