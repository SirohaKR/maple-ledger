// 성장 DB 조회 — 하루 스냅샷, 장비 정보.
import 'dart:convert';

import '../../core/db.dart';

class GrowthRepository {
  final Db db;
  GrowthRepository(this.db);

  // ── 하루 스냅샷 ──
  List<Row> searchDaily(int cid, String since) =>
      db.rows('SELECT * FROM char_daily WHERE character_id = ? AND date >= ? ORDER BY date', [cid, since]);

  Set<String> dailyDates(int cid) =>
      {for (final r in db.rows('SELECT date FROM char_daily WHERE character_id = ?', [cid])) r['date'] as String};

  bool hasDaily(int cid, String date) =>
      db.one('SELECT 1 FROM char_daily WHERE character_id = ? AND date = ?', [cid, date]) != null;

  void saveDaily(int cid, String date, Object? level, Object? exp, Object? expRate, int? combatPower) =>
      db.exec('INSERT OR REPLACE INTO char_daily VALUES (?, ?, ?, ?, ?, ?)', [cid, date, level, exp, expRate, combatPower]);

  /// 날짜별 사냥 시간(분) 합계.
  Map<String, int> huntMinutesByDate(int cid, String since) => {
        for (final r in db.rows('''SELECT date, SUM(minutes) AS m FROM hunts
            WHERE character_id = ? AND status = 'done' AND date >= ? GROUP BY date''', [cid, since]))
          if (r['m'] != null) r['date'] as String: r['m'] as int,
      };

  // ── 장비 정보 ──
  void upsertItem(String name, int? level, Object? icon, String at, Map<String, Object?> detail) => db.exec('''
      INSERT INTO item_info (name, level, icon, updated_at, detail) VALUES (?, ?, ?, ?, ?)
      ON CONFLICT (name) DO UPDATE SET
        level = COALESCE(excluded.level, item_info.level), icon = COALESCE(excluded.icon, item_info.icon),
        updated_at = excluded.updated_at, detail = excluded.detail''', [name, level, icon, at, jsonEncode(detail)]);

  Map<String, int?> itemLevels() =>
      {for (final r in db.rows('SELECT name, level FROM item_info')) r['name'] as String: r['level'] as int?};

  /// 장비 툴팁 정보 {이름: detail}.
  Map<String, Object?> itemDetails(Iterable<String> names) {
    final out = <String, Object?>{};
    for (final n in names) {
      final d = db.scalar('SELECT detail FROM item_info WHERE name = ?', [n]) as String?;
      if (d != null && d.isNotEmpty) out[n] = jsonDecode(d);
    }
    return out;
  }
}
