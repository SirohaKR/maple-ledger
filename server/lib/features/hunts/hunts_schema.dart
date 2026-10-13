// 사냥 기록 DB.
import '../../core/schema.dart';

final huntsSchema = Schema(
  tables: [
    '''CREATE TABLE IF NOT EXISTS hunts (
         id INTEGER PRIMARY KEY,
         character_id INTEGER REFERENCES characters(id) ON DELETE SET NULL,
         date TEXT NOT NULL,
         place TEXT,
         minutes INTEGER,
         meso INTEGER,
         meso_start INTEGER,
         meso_end INTEGER,
         fragments INTEGER,
         extra INTEGER,                     -- 추가 부수입 (코어 젬스톤, 장비 판매 등)
         fragments_sold INTEGER NOT NULL DEFAULT 0, -- 이 회차 조각을 팔아서 수익에 반영
         fragment_price INTEGER,            -- 저장 시점 조각 시세 (이후 시세가 바뀌어도 그대로)
         fragment_fee REAL,
         note TEXT,
         started_at TEXT,                   -- 타이머로 시작한 경우
         status TEXT NOT NULL DEFAULT 'done' CHECK (status IN ('running','done')))''',
  ],
  columns: {
    'hunts': {
      'user_id': 'INTEGER',
      'ended_at': 'TEXT',
      'extra': 'INTEGER',
      'fragments_sold': 'INTEGER NOT NULL DEFAULT 0',
      'fragment_price': 'INTEGER',
      'fragment_fee': 'REAL',
    },
  },
  after: ['CREATE INDEX IF NOT EXISTS hunts_user ON hunts(user_id)'],
);
