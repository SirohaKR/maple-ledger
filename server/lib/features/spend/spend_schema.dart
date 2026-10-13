// 지출 DB — 넥슨 강화 기록(스타포스·잠재능력·큐브), 받아온 날짜, 직접 넣는 지출.
import '../../core/schema.dart';

final spendSchema = Schema(
  tables: [
    '''CREATE TABLE IF NOT EXISTS enhance_log (
         id TEXT PRIMARY KEY,                    -- kind:넥슨 기록 id
         kind TEXT NOT NULL,                     -- starforce | potential | cube
         date TEXT NOT NULL,                     -- YYYY-MM-DD
         at TEXT,                                -- 강화 일시
         character_name TEXT, target_item TEXT, item_level INTEGER,
         before_star INTEGER, after_star INTEGER,
         result TEXT, grade TEXT, sub TEXT,      -- sub: 스타포스=특이사항, 잠재=잠재능력 종류, 큐브=큐브 이름
         destroy_defence INTEGER NOT NULL DEFAULT 0,
         cost INTEGER,                           -- 추정 비용 (NULL = 계산 불가)
         cost_manual INTEGER NOT NULL DEFAULT 0, -- 1 = 사용자가 직접 고친 비용
         raw TEXT)''',
    '''CREATE TABLE IF NOT EXISTS history_days (
         user_id INTEGER NOT NULL, kind TEXT NOT NULL, date TEXT NOT NULL, PRIMARY KEY (user_id, kind, date))''',
    '''CREATE TABLE IF NOT EXISTS expenses (
         id INTEGER PRIMARY KEY,
         date TEXT NOT NULL,
         character_id INTEGER REFERENCES characters(id) ON DELETE SET NULL,
         category TEXT NOT NULL,
         amount INTEGER NOT NULL DEFAULT 0,
         note TEXT)''',
  ],
  columns: {
    'enhance_log': {'user_id': 'INTEGER'},
    'expenses': {'user_id': 'INTEGER'},
  },
  after: [
    'CREATE INDEX IF NOT EXISTS enhance_log_user ON enhance_log(user_id)',
    'CREATE INDEX IF NOT EXISTS expenses_user ON expenses(user_id)',
    'CREATE INDEX IF NOT EXISTS enhance_log_date ON enhance_log(user_id, date)',
  ],
);
