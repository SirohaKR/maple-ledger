// 캐릭터 DB — 등록한 캐릭터, 캐릭터별 보스 프리셋.
import '../../core/schema.dart';

final charactersSchema = Schema(
  tables: [
    '''CREATE TABLE IF NOT EXISTS characters (
         id INTEGER PRIMARY KEY,
         ocid TEXT UNIQUE,
         name TEXT NOT NULL,
         world TEXT, job TEXT, level INTEGER, image TEXT,
         sort INTEGER NOT NULL DEFAULT 0,
         updated_at TEXT)''',
    '''CREATE TABLE IF NOT EXISTS char_bosses (
         character_id INTEGER NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
         boss_id INTEGER NOT NULL REFERENCES bosses(id) ON DELETE CASCADE,
         party_size INTEGER NOT NULL DEFAULT 1,
         daily_count INTEGER NOT NULL DEFAULT 7,
         PRIMARY KEY (character_id, boss_id))''',
  ],
  columns: {
    'characters': {'user_id': 'INTEGER'},
  },
  after: ['CREATE INDEX IF NOT EXISTS characters_user ON characters(user_id)'],
);
