// 사냥 기록 DB 조회. 모두 "내 기록"(user_id)만.
import '../../core/db.dart';

class HuntsRepository {
  final Db db;
  HuntsRepository(this.db);

  /// 기간·캐릭터로 찾기 (진행 중인 사냥이 맨 위).
  List<Row> search(int uid, {String? from, String? to, int? characterId}) {
    var q = '''SELECT h.*, c.name AS character_name FROM hunts h LEFT JOIN characters c ON c.id = h.character_id
               WHERE h.user_id = ?''';
    final args = <Object?>[uid];
    if (from != null) {
      q += ' AND h.date >= ?';
      args.add(from);
    }
    if (to != null) {
      q += ' AND h.date <= ?';
      args.add(to);
    }
    if (characterId != null) {
      q += ' AND h.character_id = ?';
      args.add(characterId);
    }
    return db.rows("$q ORDER BY h.status = 'running' DESC, h.date DESC, h.id DESC LIMIT 500", args);
  }

  /// 끝낸 사냥 (통계용).
  List<Row> searchDone(int uid, String since) =>
      db.rows("SELECT * FROM hunts WHERE user_id = ? AND status = 'done' AND date >= ?", [uid, since]);

  Row? find(int uid, int id) => db.one('SELECT * FROM hunts WHERE id = ? AND user_id = ?', [id, uid]);

  int insert(Map<String, Object?> h) =>
      db.insert('INSERT INTO hunts (${h.keys.join(', ')}) VALUES (${List.filled(h.length, '?').join(', ')})', [...h.values]);

  void update(int uid, int id, Map<String, Object?> h) =>
      db.exec('UPDATE hunts SET ${h.keys.map((k) => '$k = ?').join(', ')} WHERE id = ? AND user_id = ?', [...h.values, id, uid]);

  /// 타이머 멈춤 (시간 확정).
  void end(int uid, int id, String at) => db.exec(
      "UPDATE hunts SET ended_at = ? WHERE id = ? AND user_id = ? AND status = 'running' AND ended_at IS NULL", [at, id, uid]);

  /// 타이머 다시 켜기.
  void resume(int uid, int id) =>
      db.exec("UPDATE hunts SET ended_at = NULL WHERE id = ? AND user_id = ? AND status = 'running'", [id, uid]);

  void delete(int uid, int id) => db.exec('DELETE FROM hunts WHERE id = ? AND user_id = ?', [id, uid]);
}
