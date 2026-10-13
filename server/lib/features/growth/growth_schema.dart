// 성장 DB — 캐릭터 하루 스냅샷(경험치·전투력 그래프), 장비 정보(이름 → 레벨·아이콘·툴팁).
import '../../core/schema.dart';

final growthSchema = Schema(
  tables: [
    '''CREATE TABLE IF NOT EXISTS char_daily (
         character_id INTEGER NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
         date TEXT NOT NULL,
         level INTEGER, exp INTEGER, exp_rate REAL, combat_power INTEGER,
         PRIMARY KEY (character_id, date))''',
    '''CREATE TABLE IF NOT EXISTS item_info (
         name TEXT PRIMARY KEY, level INTEGER, icon TEXT, updated_at TEXT)''',
  ],
  columns: {
    'item_info': {'detail': 'TEXT'},
  },
);
