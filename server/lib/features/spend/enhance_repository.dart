// 강화 기록 DB 조회. 모두 "내 기록"(user_id)만.
import '../../core/db.dart';

class EnhanceRepository {
  final Db db;
  EnhanceRepository(this.db);

  /// 기간(·캐릭터)의 강화 기록 + 장비 아이콘·레벨.
  List<Row> search(int uid, String from, String to, String? character) => db.rows('''
      SELECT e.id, e.kind, e.date, e.at, e.character_name, e.target_item, e.item_level, e.before_star,
             e.after_star, e.result, e.grade, e.sub, e.destroy_defence, e.cost, e.cost_manual,
             i.icon, COALESCE(e.item_level, i.level) AS level
      FROM enhance_log e LEFT JOIN item_info i ON i.name = e.target_item
      WHERE e.user_id = ? AND e.date BETWEEN ? AND ? AND (? IS NULL OR e.character_name = ?)
      ORDER BY e.at DESC LIMIT 3000''', [uid, from, to, character, character]);

  /// 캐릭터별 횟수·비용.
  List<Row> perCharacter(int uid, String from, String to) => db.rows('''
      SELECT character_name AS name, COUNT(*) AS n, COALESCE(SUM(cost), 0) AS cost FROM enhance_log
      WHERE user_id = ? AND date BETWEEN ? AND ? GROUP BY character_name ORDER BY n DESC''', [uid, from, to]);

  /// 비용이 있는 기록 (통계용).
  List<Row> searchCosts(int uid, String since) => db.rows(
      'SELECT character_name, date, cost FROM enhance_log WHERE user_id = ? AND cost IS NOT NULL AND date >= ?', [uid, since]);

  /// 넥슨 기록 저장 (이미 있으면 그대로) — 새로 들어갔으면 1.
  int insert(Map<String, Object?> row) => db.exec(
      'INSERT OR IGNORE INTO enhance_log (${row.keys.join(', ')}) VALUES (${List.filled(row.length, '?').join(', ')})',
      [...row.values]);

  /// 아직 비용을 못 정한 기록 (직접 고친 것 제외).
  List<Row> searchUnpriced(int uid) =>
      db.rows('SELECT * FROM enhance_log WHERE cost IS NULL AND cost_manual = 0 AND user_id = ?', [uid]);

  void setCost(String id, int cost) => db.exec('UPDATE enhance_log SET cost = ? WHERE id = ?', [cost, id]);

  void setManualCost(int uid, String id, int cost) =>
      db.exec('UPDATE enhance_log SET cost = ?, cost_manual = 1 WHERE id = ? AND user_id = ?', [cost, id, uid]);

  void resetCost(int uid, String id) =>
      db.exec('UPDATE enhance_log SET cost = NULL, cost_manual = 0 WHERE id = ? AND user_id = ?', [id, uid]);

  /// 스타포스 비용 계산에 필요한 장비 레벨을 모르는 캐릭터 이름들.
  Set<String> charsWithUnknownItems(int uid) => {
        for (final r in db.rows('''
            SELECT DISTINCT e.character_name FROM enhance_log e LEFT JOIN item_info i ON i.name = e.target_item
            WHERE e.user_id = ? AND e.kind = 'starforce' AND e.cost IS NULL AND i.level IS NULL''', [uid]))
          if (r['character_name'] != null && r['character_name'] != '') r['character_name'] as String,
      };

  // ── 이미 받아온 날짜 ──
  Set<(String, String)> doneDays(int uid) =>
      {for (final r in db.rows('SELECT kind, date FROM history_days WHERE user_id = ?', [uid])) (r['kind'] as String, r['date'] as String)};

  void markDay(int uid, String kind, String date) =>
      db.exec('INSERT OR IGNORE INTO history_days VALUES (?, ?, ?)', [uid, kind, date]);
}
