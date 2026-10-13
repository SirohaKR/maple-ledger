// 업데이트 내역 DB — 관리자가 다듬어서 저장·게시한 글.
import '../../core/db.dart';
import '../../core/schema.dart';

final changelogSchema = Schema(
  tables: [
    '''CREATE TABLE IF NOT EXISTS changelog_posts (
         version TEXT PRIMARY KEY,
         date TEXT,
         body TEXT,
         published INTEGER NOT NULL DEFAULT 0,  -- 1 = 게시
         hidden INTEGER NOT NULL DEFAULT 0,     -- 1 = 게시했지만 숨김
         updated_at TEXT)''',
  ],
  seed: _resetForV1,
);

/// 정식 v1.0부터 버전을 새로 센다 — 그 전(파이썬 시절 v1.1, v1.2 …)에 게시한 글은 한 번만 지운다.
void _resetForV1(Db db) {
  if (db.scalar("SELECT value FROM settings WHERE key = 'changelog_reset_v1'") != null) return;
  db.exec('DELETE FROM changelog_posts');
  db.exec("INSERT INTO settings VALUES ('changelog_reset_v1', '1')");
}
