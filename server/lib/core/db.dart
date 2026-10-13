// DB 연결 — SQLite 파일 하나 (data/ledger.db). Python 버전과 같은 파일·같은 구조라 그대로 이어 쓴다.
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

typedef Row = Map<String, Object?>;

class Db {
  final Database raw;

  Db._(this.raw);

  factory Db.open(String path) {
    Directory(p.dirname(path)).createSync(recursive: true);
    final raw = sqlite3.open(path);
    raw.execute('PRAGMA foreign_keys = ON');
    raw.execute('PRAGMA busy_timeout = 5000');
    return Db._(raw);
  }

  factory Db.memory() {
    final raw = sqlite3.openInMemory();
    raw.execute('PRAGMA foreign_keys = ON');
    return Db._(raw);
  }

  /// 여러 줄 조회.
  List<Row> rows(String sql, [List<Object?> args = const []]) =>
      raw.select(sql, args).map((r) => Map<String, Object?>.from(r)).toList();

  /// 한 줄 조회 (없으면 null).
  Row? one(String sql, [List<Object?> args = const []]) {
    final rs = raw.select(sql, args);
    return rs.isEmpty ? null : Map<String, Object?>.from(rs.first);
  }

  /// 값 하나 조회 (첫 줄 첫 칸).
  Object? scalar(String sql, [List<Object?> args = const []]) {
    final rs = raw.select(sql, args);
    return rs.isEmpty ? null : rs.first.values.first;
  }

  /// INSERT/UPDATE/DELETE — 바뀐 줄 수를 돌려준다.
  int exec(String sql, [List<Object?> args = const []]) {
    raw.execute(sql, args);
    return raw.updatedRows;
  }

  /// INSERT 후 새 id.
  int insert(String sql, [List<Object?> args = const []]) {
    raw.execute(sql, args);
    return raw.lastInsertRowId;
  }

  /// 여러 문장을 한 번에 (실패하면 전부 취소).
  T tx<T>(T Function() fn) {
    raw.execute('BEGIN');
    try {
      final r = fn();
      raw.execute('COMMIT');
      return r;
    } catch (_) {
      raw.execute('ROLLBACK');
      rethrow;
    }
  }

  /// 테이블에 칸이 없으면 추가 (예전 DB 호환).
  void addColumns(String table, Map<String, String> cols) {
    final have = rows('PRAGMA table_info($table)').map((r) => r['name']).toSet();
    for (final e in cols.entries) {
      if (!have.contains(e.key)) raw.execute('ALTER TABLE $table ADD COLUMN ${e.key} ${e.value}');
    }
  }

  void close() => raw.close();
}
