// 직접 넣는 지출 DB 조회. 모두 "내 기록"(user_id)만.
import '../../core/db.dart';

class ExpensesRepository {
  final Db db;
  ExpensesRepository(this.db);

  List<Row> search(int uid, String from) => db.rows('''
      SELECT x.*, c.name AS character_name FROM expenses x LEFT JOIN characters c ON c.id = x.character_id
      WHERE x.user_id = ? AND x.date >= ? ORDER BY x.date DESC, x.id DESC LIMIT 500''', [uid, from]);

  /// 통계용.
  List<Row> searchSince(int uid, String since) =>
      db.rows('SELECT character_id, date, amount FROM expenses WHERE user_id = ? AND date >= ?', [uid, since]);

  int insert(Map<String, Object?> r) =>
      db.insert('INSERT INTO expenses (${r.keys.join(', ')}) VALUES (${List.filled(r.length, '?').join(', ')})', [...r.values]);

  void update(int uid, int id, Map<String, Object?> r) =>
      db.exec('UPDATE expenses SET ${r.keys.map((k) => '$k = ?').join(', ')} WHERE id = ? AND user_id = ?', [...r.values, id, uid]);

  void delete(int uid, int id) => db.exec('DELETE FROM expenses WHERE id = ? AND user_id = ?', [id, uid]);
}
