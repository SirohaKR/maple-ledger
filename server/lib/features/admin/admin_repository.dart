// 관리 화면 DB 조회 — 사용자 목록, 사용자 삭제.
import '../../core/db.dart';

class AdminRepository {
  final Db db;
  AdminRepository(this.db);

  /// 사용자 목록 (캐릭터 수, API 키 등록 여부 포함).
  List<Row> searchUsers() => db.rows('''
      SELECT u.id, u.username, u.is_admin, u.created_at,
             (SELECT COUNT(*) FROM characters c WHERE c.user_id = u.id) AS chars,
             EXISTS (SELECT 1 FROM user_settings s WHERE s.user_id = u.id AND s.key = 'nexon_api_key') AS has_key
      FROM users u ORDER BY u.id''');

  String inviteCode() => db.scalar("SELECT value FROM settings WHERE key = 'invite_code'") as String? ?? '';

  void setInviteCode(String code) => db.exec("INSERT OR REPLACE INTO settings VALUES ('invite_code', ?)", [code]);

  void setAdmin(int userId, bool admin) => db.exec('UPDATE users SET is_admin = ? WHERE id = ?', [admin ? 1 : 0, userId]);

  /// 사용자와 그 사람의 모든 기록 삭제.
  void deleteUser(int userId) => db.tx(() {
        for (final t in ['characters', 'incomes', 'expenses', 'enhance_log', 'hunts', 'history_days']) {
          db.exec('DELETE FROM $t WHERE user_id = ?', [userId]);
        }
        db.exec('DELETE FROM users WHERE id = ?', [userId]);
      });
}
