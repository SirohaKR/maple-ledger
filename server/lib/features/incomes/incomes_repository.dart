// 기타 수익 DB 조회. 모두 "내 기록"(user_id)만.
import '../../core/db.dart';

class IncomesRepository {
  final Db db;
  IncomesRepository(this.db);

  /// 기간·종류로 찾기 (안 판 것이 맨 위).
  List<Row> search(int uid, {String? from, String? to, String? kind}) {
    var q = '''SELECT i.*, c.name AS character_name, b.name AS boss_name, b.difficulty AS boss_difficulty
               FROM incomes i LEFT JOIN characters c ON c.id = i.character_id
               LEFT JOIN bosses b ON b.id = i.boss_id WHERE i.user_id = ?''';
    final args = <Object?>[uid];
    for (final (v, cond) in [(from, 'i.date >= ?'), (to, 'i.date <= ?'), (kind, 'i.kind = ?')]) {
      if (v != null) {
        q += ' AND $cond';
        args.add(v);
      }
    }
    return db.rows('$q ORDER BY i.sold ASC, i.date DESC, i.id DESC LIMIT 500', args);
  }

  /// 판 것만 (통계용).
  List<Row> searchSold(int uid, String since) =>
      db.rows('SELECT character_id, date, amount FROM incomes WHERE user_id = ? AND sold = 1 AND date >= ?', [uid, since]);

  /// 아직 안 판 것의 개수·금액.
  Row pending(int uid) => db.one(
      'SELECT COUNT(*) AS count, COALESCE(SUM(amount), 0) AS amount FROM incomes WHERE user_id = ? AND sold = 0', [uid])!;

  /// 개인 시세: 팔린 드랍 아이템의 1개당 판매가(수수료 전) 평균·최근값.
  List<Row> prices(int uid) => db.rows('''
      SELECT title, COUNT(*) AS n, AVG(gross * 1.0 / qty) AS avg,
             (SELECT gross * 1.0 / qty FROM incomes j WHERE j.title = i.title AND j.sold = 1 AND j.user_id = i.user_id
              ORDER BY j.date DESC, j.id DESC LIMIT 1) AS last
      FROM incomes i WHERE user_id = ? AND sold = 1 AND title IS NOT NULL AND kind = 'drop'
      GROUP BY title ORDER BY n DESC, title''', [uid]);

  int insert(Map<String, Object?> r) =>
      db.insert('INSERT INTO incomes (${r.keys.join(', ')}) VALUES (${List.filled(r.length, '?').join(', ')})', [...r.values]);

  void update(int uid, int id, Map<String, Object?> r) =>
      db.exec('UPDATE incomes SET ${r.keys.map((k) => '$k = ?').join(', ')} WHERE id = ? AND user_id = ?', [...r.values, id, uid]);

  void delete(int uid, int id) => db.exec('DELETE FROM incomes WHERE id = ? AND user_id = ?', [id, uid]);
}
