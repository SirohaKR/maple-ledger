// 보스 자동 체크 DB — 지난 날짜 스케줄러를 받아온 기록, 마지막 스케줄러 응답(숙제 체크리스트용).
import '../../core/schema.dart';

final syncSchema = Schema(
  tables: [
    '''CREATE TABLE IF NOT EXISTS sync_days (
         character_id INTEGER NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
         date TEXT NOT NULL,
         PRIMARY KEY (character_id, date))''',
    '''CREATE TABLE IF NOT EXISTS sched_state (
         character_id INTEGER PRIMARY KEY REFERENCES characters(id) ON DELETE CASCADE,
         fetched_at TEXT, data TEXT)''',
  ],
);
