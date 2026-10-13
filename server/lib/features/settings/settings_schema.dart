// 설정 화면의 DB — 같이 쓰는 설정, 사람별 설정, 결정석 판매 규칙.
import '../../core/schema.dart';

/// 결정석 판매 규칙 기본값 (적용일, 캐릭터당 한도, 월드당 한도, 일간 결정석 포함). 0 = 제한 없음.
/// 2026-09-17 패치로 캐릭터당 12개 제한이 풀리고 월드당 90개만 남았다.
const defaultRules = [
  ['2000-01-01', 12, 90, 1],
  ['2026-09-17', 0, 90, 1],
];

final settingsSchema = Schema(
  tables: [
    '''CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT)''',
    '''CREATE TABLE IF NOT EXISTS user_settings (
         user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
         key TEXT NOT NULL, value TEXT,
         PRIMARY KEY (user_id, key))''',
    '''CREATE TABLE IF NOT EXISTS crystal_rules (
         id INTEGER PRIMARY KEY,
         effective_from TEXT NOT NULL UNIQUE,
         char_limit INTEGER NOT NULL DEFAULT 0,    -- 캐릭터당 주간 판매 개수 (0 = 무제한)
         world_limit INTEGER NOT NULL DEFAULT 0,   -- 월드당 주간 판매 개수 (0 = 무제한)
         daily_in_limit INTEGER NOT NULL DEFAULT 1 -- 일간 보스 결정석도 한도에 포함
       )''',
  ],
  seed: (db) {
    db.exec("INSERT OR IGNORE INTO settings VALUES ('notice_keywords', '결정석')");
    // 예전 버전의 단일 한도 설정은 규칙 테이블로 옮겨졌다
    db.exec("DELETE FROM settings WHERE key IN ('weekly_limit', 'world_limit', 'daily_in_limit')");
    if (db.scalar('SELECT COUNT(*) FROM crystal_rules') == 0) {
      for (final r in defaultRules) {
        db.exec('INSERT INTO crystal_rules (effective_from, char_limit, world_limit, daily_in_limit) VALUES (?, ?, ?, ?)', r);
      }
    }
  },
);
