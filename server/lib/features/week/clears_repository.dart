// 보스 클리어 기록 DB 조회. 모두 "내 캐릭터" 기준.
import '../../core/db.dart';

class ClearsRepository {
  final Db db;
  ClearsRepository(this.db);

  /// 그 주의 일간·주간 보스 클리어 (보스 정보·캐릭터 월드 포함).
  List<Row> searchWeek(int uid, String week) => db.rows('''
      SELECT c.id, c.character_id, c.boss_id, c.count, c.party_size, c.source,
             b.name, b.difficulty, b.cycle, ch.world
      FROM clears c JOIN bosses b ON b.id = c.boss_id
      JOIN characters ch ON ch.id = c.character_id
      WHERE c.period = ? AND b.cycle IN ('daily','weekly') AND ch.user_id = ?
      ORDER BY b.sort''', [week, uid]);

  /// 그 달의 월간 보스 클리어.
  List<Row> searchMonth(int uid, String month) => db.rows('''
      SELECT c.id, c.character_id, c.boss_id, c.count, c.party_size, c.source,
             b.name, b.difficulty, b.cycle
      FROM clears c JOIN bosses b ON b.id = c.boss_id
      JOIN characters ch ON ch.id = c.character_id
      WHERE c.period = ? AND b.cycle = 'monthly' AND ch.user_id = ?
      ORDER BY b.sort''', [month, uid]);

  void delete(int cid, int bid, String period) =>
      db.exec('DELETE FROM clears WHERE character_id = ? AND boss_id = ? AND period = ?', [cid, bid, period]);

  /// 직접 체크 (있으면 횟수·파티만 바꾸고 출처는 직접(manual)으로).
  void upsertManual(int cid, int bid, String period, int count, int party) => db.exec('''
      INSERT INTO clears (character_id, boss_id, period, count, party_size) VALUES (?, ?, ?, ?, ?)
      ON CONFLICT (character_id, boss_id, period)
      DO UPDATE SET count = excluded.count, party_size = excluded.party_size, source = 'manual\'''',
      [cid, bid, period, count, party]);

  /// 자동 체크로 추가 (이미 있으면 그대로) — 새로 추가됐으면 true.
  bool insertFromApi(int cid, int bid, String period, int party) =>
      db.exec("INSERT OR IGNORE INTO clears (character_id, boss_id, period, count, party_size, source) VALUES (?, ?, ?, 1, ?, 'api')",
          [cid, bid, period, party]) >
      0;

  /// 일간 보스 횟수를 자동 체크 값으로 (직접 넣은 횟수가 더 크면 그대로).
  void upsertDailyFromApi(int cid, int bid, String week, int count, int party) => db.exec('''
      INSERT INTO clears (character_id, boss_id, period, count, party_size, source) VALUES (?, ?, ?, ?, ?, 'api')
      ON CONFLICT (character_id, boss_id, period) DO UPDATE SET count = MAX(count, excluded.count)''',
      [cid, bid, week, count, party]);

  /// 프리셋 그대로 이번 주 클리어 체크 (이미 체크한 건 그대로).
  void fillFromPreset(int uid, String week, {int? characterId}) => db.exec('''
      INSERT OR IGNORE INTO clears (character_id, boss_id, period, count, party_size)
      SELECT p.character_id, p.boss_id, ?,
             CASE WHEN bo.cycle = 'daily' THEN p.daily_count ELSE 1 END, p.party_size
      FROM char_bosses p JOIN bosses bo ON bo.id = p.boss_id
      JOIN characters ch ON ch.id = p.character_id
      WHERE bo.cycle IN ('daily','weekly') AND ch.user_id = ? ${characterId != null ? 'AND p.character_id = ?' : ''}''',
      [week, uid, if (characterId != null) characterId]);

  // ── 일간 보스 날짜별 기록 (자동 체크) ──
  void logDaily(int cid, int bid, String date) => db.exec('INSERT OR IGNORE INTO boss_log VALUES (?, ?, ?)', [cid, bid, date]);

  /// 이번 주 일간 보스별 완료한 날 수.
  List<Row> dailyCounts(int cid, String weekStart, String weekEnd) => db.rows('''
      SELECT boss_id, COUNT(*) AS n FROM boss_log
      WHERE character_id = ? AND date >= ? AND date < ? GROUP BY boss_id''', [cid, weekStart, weekEnd]);
}
