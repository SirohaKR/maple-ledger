// 보스 가격표 DB — 보스 목록, 결정석 가격 이력(적용일별).
import '../../core/schema.dart';
import 'bosses_seed.dart';

final bossesSchema = Schema(
  tables: [
    '''CREATE TABLE IF NOT EXISTS bosses (
         id INTEGER PRIMARY KEY,
         name TEXT NOT NULL,
         difficulty TEXT NOT NULL,
         cycle TEXT NOT NULL CHECK (cycle IN ('daily','weekly','monthly')),
         max_party INTEGER NOT NULL DEFAULT 6,
         sort INTEGER NOT NULL DEFAULT 0,
         hidden INTEGER NOT NULL DEFAULT 0,
         api_name TEXT,                     -- 스케줄러 API의 보스 이름이 다를 때 매칭용 별칭
         image_url TEXT,                    -- 보스 이미지 (넥슨 API에 없어서 직접 넣는다)
         UNIQUE (name, difficulty, cycle))''',
    '''CREATE TABLE IF NOT EXISTS boss_prices (
         id INTEGER PRIMARY KEY,
         boss_id INTEGER NOT NULL REFERENCES bosses(id) ON DELETE CASCADE,
         price INTEGER NOT NULL,
         effective_from TEXT NOT NULL,
         UNIQUE (boss_id, effective_from))''',
  ],
  columns: {
    'bosses': {'api_name': 'TEXT', 'image_url': 'TEXT'},
  },
  seed: (db) {
    if (db.scalar('SELECT COUNT(*) FROM bosses') != 0) return;
    db.tx(() {
      var i = 0;
      for (final (name, diff, cycle, price, eff) in seedRows()) {
        final id = db.insert('INSERT INTO bosses (name, difficulty, cycle, sort) VALUES (?, ?, ?, ?)', [name, diff, cycle, i++]);
        db.exec('INSERT INTO boss_prices (boss_id, price, effective_from) VALUES (?, ?, ?)', [id, price, eff]);
      }
    });
  },
);
