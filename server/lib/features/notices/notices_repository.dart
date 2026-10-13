// 공지 DB 조회.
import '../../core/db.dart';

class NoticesRepository {
  final Db db;
  NoticesRepository(this.db);

  List<Row> search() => db.rows('SELECT * FROM notices ORDER BY date DESC, id DESC LIMIT 200');

  bool isEmpty() => db.scalar('SELECT COUNT(*) FROM notices') == 0;

  bool exists(String id) => db.one('SELECT 1 FROM notices WHERE id = ?', [id]) != null;

  void insert(Map<String, Object?> n) =>
      db.exec('INSERT INTO notices (${n.keys.join(', ')}) VALUES (${List.filled(n.length, '?').join(', ')})', [...n.values]);

  /// 내가 확인한 알림 id들.
  Set<String> seenBy(int uid) =>
      {for (final r in db.rows('SELECT notice_id FROM notice_seen WHERE user_id = ?', [uid])) r['notice_id'] as String};

  /// 지금 있는 알림을 전부 확인한 걸로.
  void markAllSeen(int uid) =>
      db.exec('INSERT OR IGNORE INTO notice_seen SELECT ?, id FROM notices WHERE matched IS NOT NULL', [uid]);

  /// 공지 확인에 쓸 API 키 주인 (관리자 먼저).
  int? keyOwner() => db.scalar('''
      SELECT s.user_id FROM user_settings s JOIN users u ON u.id = s.user_id
      WHERE s.key = 'nexon_api_key' AND s.value <> '' ORDER BY u.is_admin DESC, u.id LIMIT 1''') as int?;
}
