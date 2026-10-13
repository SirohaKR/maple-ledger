// 로그인 DB — 계정, 로그인 세션.
import '../../core/schema.dart';

final authSchema = Schema(tables: [
  '''CREATE TABLE IF NOT EXISTS users (
       id INTEGER PRIMARY KEY,
       username TEXT NOT NULL UNIQUE,
       pw_hash TEXT NOT NULL,
       is_admin INTEGER NOT NULL DEFAULT 0,
       created_at TEXT)''',
  // 로그인 유지 (쿠키의 토큰 → 사용자). Python 버전엔 없던 표라, 바꾼 뒤 한 번은 다시 로그인해야 한다.
  '''CREATE TABLE IF NOT EXISTS sessions (
       token TEXT PRIMARY KEY,
       user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
       expires_at TEXT NOT NULL)''',
]);
