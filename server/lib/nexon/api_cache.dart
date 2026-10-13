// 넥슨 응답 캐시 — 장비·HEXA·심볼처럼 자주 안 바뀌는 응답을 DB에 잠깐 둔다 (API 호출 절약).
import 'dart:convert';

import '../core/db.dart';
import '../core/schema.dart';

final apiCacheSchema = Schema(tables: [
  'CREATE TABLE IF NOT EXISTS api_cache (key TEXT PRIMARY KEY, fetched_at REAL, data TEXT)',
]);

double _now() => DateTime.now().millisecondsSinceEpoch / 1000;

class ApiCache {
  final Db db;
  ApiCache(this.db);

  /// ttl(초) 안에 받은 적 있으면 저장해 둔 응답, 아니면 새로 받아서 저장.
  Future<T> cached<T>(String key, int ttl, Future<T> Function() fn) async {
    final row = db.one('SELECT fetched_at, data FROM api_cache WHERE key = ?', [key]);
    if (row != null && _now() - (row['fetched_at'] as num) < ttl) return jsonDecode(row['data'] as String) as T;
    final data = await fn();
    db.exec('INSERT OR REPLACE INTO api_cache VALUES (?, ?, ?)', [key, _now(), jsonEncode(data)]);
    return data;
  }
}
