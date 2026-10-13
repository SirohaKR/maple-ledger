// 공지 DB — 넥슨 공지(키워드 감시, 모두가 같이 봄), 누가 알림을 확인했는지.
import '../../core/schema.dart';

final noticesSchema = Schema(
  tables: [
    '''CREATE TABLE IF NOT EXISTS notices (
         id TEXT PRIMARY KEY,                    -- kind:notice_id
         kind TEXT, title TEXT, url TEXT, date TEXT,
         matched TEXT,                           -- 찾은 키워드 (쉼표)
         seen INTEGER NOT NULL DEFAULT 0,        -- 1 = 처음 불러올 때 이미 있던 공지
         date_start TEXT, date_end TEXT)''',
    '''CREATE TABLE IF NOT EXISTS notice_seen (
         user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
         notice_id TEXT NOT NULL,
         PRIMARY KEY (user_id, notice_id))''',
  ],
  columns: {
    'notices': {'date_start': 'TEXT', 'date_end': 'TEXT'},
  },
);
