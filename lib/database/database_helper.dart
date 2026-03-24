import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/subscription.dart';
import '../utils/app_constants.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();
  
  // 為替レートの簡易取得用（本来はExchangeRateServiceから取得すべきだが、既存コードとの互換性のため定義）
  Map<String, double> get exchangeRates => {
        'JPY': 1.0,
        'USD': 150.0, // 仮の固定レート
        'EUR': 160.0, // 仮の固定レート
      };

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('substop.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return openDatabase(
      path,
      version: 9,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _safeAddColumn(
        db,
        'subscriptions',
        'category',
        'TEXT DEFAULT "${AppConstants.uncategorized}"',
      );
      await _safeAddColumn(
        db,
        'subscriptions',
        'notify_type',
        'TEXT DEFAULT "1_day_before"',
      );
    }

    if (oldVersion < 3) {
      await _safeAddColumn(
        db,
        'subscriptions',
        'payment_method',
        'TEXT DEFAULT ""',
      );
      await _safeAddColumn(db, 'subscriptions', 'icon_name', 'TEXT DEFAULT "generic"');
      await _safeAddColumn(
        db,
        'subscriptions',
        'icon_color_value',
        'INTEGER DEFAULT 4283191295',
      );
      await db.execute(
        'CREATE TABLE IF NOT EXISTS payment_methods_history ('
        'id INTEGER PRIMARY KEY AUTOINCREMENT, '
        'name TEXT UNIQUE'
        ')',
      );
    }

    if (oldVersion < 4) {
      await _safeAddColumn(
        db,
        'subscriptions',
        'billing_type',
        'TEXT DEFAULT "relative"',
      );
      await _safeAddColumn(db, 'subscriptions', 'trial_days', 'INTEGER DEFAULT 31');
      await _safeAddColumn(db, 'subscriptions', 'start_date', 'TEXT');
      await _safeAddColumn(db, 'subscriptions', 'memo', 'TEXT DEFAULT ""');
    }

    if (oldVersion < 5) {
      await _safeAddColumn(db, 'subscriptions', 'currency', 'TEXT DEFAULT "JPY"');
    }

    if (oldVersion < 6) {
      const expectedColumns = <String>[
        'currency',
        'category',
        'notify_type',
        'payment_method',
        'icon_name',
        'icon_color_value',
        'billing_type',
        'trial_days',
        'start_date',
        'memo',
      ];

      for (final column in expectedColumns) {
        await _safeAddColumn(db, 'subscriptions', column, _getColumnDef(column));
      }
    }

    if (oldVersion < 7) {
      await _safeAddColumn(
        db,
        'subscriptions',
        'is_archived',
        'INTEGER NOT NULL DEFAULT 0',
      );
    }

    if (oldVersion < 8) {
      await _safeAddColumn(
        db,
        'payment_methods_history',
        'name',
        'TEXT UNIQUE',
      );
      await _safeAddColumn(
        db,
        'payment_methods_history',
        'last_used_at',
        'TEXT NOT NULL DEFAULT ""',
      );
    }

    if (oldVersion < 9) {
      await db.execute(
        'CREATE TABLE IF NOT EXISTS categories ('
        'id INTEGER PRIMARY KEY AUTOINCREMENT, '
        'name TEXT UNIQUE'
        ')',
      );
      // 初期データの投入
      final initialCategories = ['未分類', 'エンタメ', '仕事・学習', '生活インフラ', '金融・保険', 'その他'];
      for (final cat in initialCategories) {
        await db.insert('categories', {'name': cat}, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }
  }

  static String _getColumnDef(String column) {
    switch (column) {
      case 'currency':
        return 'TEXT DEFAULT "JPY"';
      case 'category':
        return 'TEXT DEFAULT "${AppConstants.uncategorized}"';
      case 'notify_type':
        return 'TEXT DEFAULT "1_day_before"';
      case 'payment_method':
        return 'TEXT DEFAULT ""';
      case 'icon_name':
        return 'TEXT DEFAULT "generic"';
      case 'icon_color_value':
        return 'INTEGER DEFAULT 4283191295';
      case 'billing_type':
        return 'TEXT DEFAULT "relative"';
      case 'trial_days':
        return 'INTEGER DEFAULT 31';
      case 'start_date':
        return 'TEXT';
      case 'memo':
        return 'TEXT DEFAULT ""';
      case 'is_archived':
        return 'INTEGER NOT NULL DEFAULT 0';
      default:
        return 'TEXT';
    }
  }

  Future<void> _safeAddColumn(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    try {
      final columns = await db.rawQuery('PRAGMA table_info($table)');
      final exists = columns.any((c) => c['name'] == column);
      if (!exists) {
        await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
      }
    } catch (_) {
      // Older installs may already be partially migrated. Skip duplicate failures.
    }
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE subscriptions(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        currency TEXT DEFAULT "JPY",
        cycle TEXT NOT NULL,
        next_billing_date TEXT NOT NULL,
        cancellation_rule TEXT NOT NULL,
        offset_days INTEGER NOT NULL,
        category TEXT DEFAULT "${AppConstants.uncategorized}",
        notify_type TEXT DEFAULT "1_day_before",
        payment_method TEXT DEFAULT "",
        icon_name TEXT DEFAULT "generic",
        icon_color_value INTEGER DEFAULT 4283191295,
        is_cancelled INTEGER NOT NULL DEFAULT 0,
        billing_type TEXT DEFAULT "relative",
        trial_days INTEGER DEFAULT 31,
        start_date TEXT,
        memo TEXT DEFAULT "",
        is_archived INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE
      )
    ''');

    // 初期データの投入
    final initialCategories = ['未分類', 'エンタメ', '仕事・学習', '生活インフラ', '金融・保険', 'その他'];
    for (final cat in initialCategories) {
      await db.insert('categories', {'name': cat});
    }

    await db.execute('''
      CREATE TABLE payment_methods_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE,
        last_used_at TEXT NOT NULL DEFAULT ""
      )
    ''');
  }

  Future<void> insertSubscription(Subscription sub) async {
    final db = await instance.database;
    await db.insert(
      'subscriptions',
      sub.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Subscription>> readAllSubscriptions() async {
    final db = await instance.database;
    final result = await db.query('subscriptions');
    return result.map(Subscription.fromMap).toList();
  }

  Future<void> updateSubscription(Subscription sub) async {
    final db = await instance.database;
    await db.update(
      'subscriptions',
      sub.toMap(),
      where: 'id = ?',
      whereArgs: [sub.id],
    );
  }

  Future<void> deleteSubscription(String id) async {
    final db = await instance.database;
    await db.delete(
      'subscriptions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> insertPaymentMethod(String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return;

    final db = await instance.database;
    await db.insert(
      'payment_methods_history',
      {
        'name': trimmedName,
        'last_used_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<String>> readAllPaymentMethods() async {
    final db = await instance.database;
    final result = await db.query(
      'payment_methods_history',
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return result.map((e) => e['name'] as String).toList();
  }

  Future<void> deletePaymentMethod(String name) async {
    final db = await instance.database;
    await db.delete(
      'payment_methods_history',
      where: 'name = ?',
      whereArgs: [name],
    );
  }

  // カテゴリ管理用
  Future<void> insertCategory(String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return;

    final db = await instance.database;
    await db.insert(
      'categories',
      {'name': trimmedName},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<String>> readAllCategories() async {
    final db = await instance.database;
    final result = await db.query('categories', orderBy: 'id ASC');
    return result.map((e) => e['name'] as String).toList();
  }

  Future<void> deleteCategory(String name) async {
    final db = await instance.database;
    await db.delete(
      'categories',
      where: 'name = ?',
      whereArgs: [name],
    );
  }
}
