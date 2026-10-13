// 업데이트 내역 DB — 관리자가 다듬어서 저장·게시한 글.
import '../../core/schema.dart';

final changelogSchema = Schema(tables: [
  '''CREATE TABLE IF NOT EXISTS changelog_posts (
       version TEXT PRIMARY KEY,
       date TEXT,
       body TEXT,
       published INTEGER NOT NULL DEFAULT 0,  -- 1 = 게시
       hidden INTEGER NOT NULL DEFAULT 0,     -- 1 = 게시했지만 숨김
       updated_at TEXT)''',
]);
