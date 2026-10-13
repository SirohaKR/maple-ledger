// 보스 기록 DB — 보스 클리어 기록, 자동 체크로 확인한 일간 보스 날짜별 기록.
import '../../core/schema.dart';

final weekSchema = Schema(
  tables: [
    '''CREATE TABLE IF NOT EXISTS clears (
         id INTEGER PRIMARY KEY,
         character_id INTEGER NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
         boss_id INTEGER NOT NULL REFERENCES bosses(id) ON DELETE CASCADE,
         period TEXT NOT NULL,              -- 주간/일간: 주 시작일(목) YYYY-MM-DD, 월간: YYYY-MM
         count INTEGER NOT NULL DEFAULT 1,  -- 일간 보스는 그 주에 잡은 횟수
         party_size INTEGER NOT NULL DEFAULT 1,
         source TEXT NOT NULL DEFAULT 'manual', -- manual | api(자동 체크)
         UNIQUE (character_id, boss_id, period))''',
    '''CREATE TABLE IF NOT EXISTS boss_log (
         character_id INTEGER NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
         boss_id INTEGER NOT NULL REFERENCES bosses(id) ON DELETE CASCADE,
         date TEXT NOT NULL,
         PRIMARY KEY (character_id, boss_id, date))''',
  ],
  columns: {
    'clears': {'source': "TEXT NOT NULL DEFAULT 'manual'"},
  },
);
