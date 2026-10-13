// 기타 수익 DB — 보스 드랍·조각 판매·부수입 등.
import '../../core/schema.dart';

final incomesSchema = Schema(
  tables: [
    '''CREATE TABLE IF NOT EXISTS incomes (
         id INTEGER PRIMARY KEY,
         date TEXT NOT NULL,
         character_id INTEGER REFERENCES characters(id) ON DELETE SET NULL,
         kind TEXT NOT NULL DEFAULT 'etc' CHECK (kind IN ('drop','fragment','side','etc')),
         boss_id INTEGER REFERENCES bosses(id) ON DELETE SET NULL,
         title TEXT,
         qty INTEGER NOT NULL DEFAULT 1,
         gross INTEGER NOT NULL DEFAULT 0,  -- 판매 총액(수수료·분배 전)
         fee_rate REAL NOT NULL DEFAULT 0,  -- %
         party_size INTEGER NOT NULL DEFAULT 1,
         split TEXT NOT NULL DEFAULT 'equal' CHECK (split IN ('equal','ratio')),
         role TEXT NOT NULL DEFAULT 'leader' CHECK (role IN ('leader','member')),
         leader_ratio INTEGER NOT NULL DEFAULT 1,
         member_ratio INTEGER NOT NULL DEFAULT 1,
         sold INTEGER NOT NULL DEFAULT 1,   -- 0 = 아직 안 팜 (합계 제외)
         amount INTEGER NOT NULL DEFAULT 0, -- 내 실수령액 (계산값)
         note TEXT)''',
  ],
  columns: {
    'incomes': {'user_id': 'INTEGER'},
  },
  after: ['CREATE INDEX IF NOT EXISTS incomes_user ON incomes(user_id)'],
);
