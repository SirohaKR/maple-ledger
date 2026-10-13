// 계정·세션 DB 조회.
import 'package:shared/shared.dart';

import '../../core/db.dart';
import '../../core/passwords.dart';

const sessionDays = 30;

class AuthRepository {
  final Db db;
  AuthRepository(this.db);

  int countUsers() => db.scalar('SELECT COUNT(*) FROM users') as int;

  Row? findUser(int id) => db.one('SELECT * FROM users WHERE id = ?', [id]);

  Row? findByName(String username) => db.one('SELECT * FROM users WHERE username = ?', [username]);

  /// 새 계정 (아이디가 겹치면 null).
  int? createUser(String username, String pwHash, {required bool admin}) {
    if (findByName(username) != null) return null;
    return db.insert('INSERT INTO users (username, pw_hash, is_admin, created_at) VALUES (?, ?, ?, ?)',
        [username, pwHash, admin ? 1 : 0, nowKstIso()]);
  }

  void setPassword(int id, String pwHash) => db.exec('UPDATE users SET pw_hash = ? WHERE id = ?', [pwHash, id]);

  Map<String, Object?> me(int id) {
    final u = findUser(id)!;
    return {'id': u['id'], 'username': u['username'], 'is_admin': u['is_admin'] == 1};
  }

  // ── 세션 ──
  String createSession(int userId) {
    final token = randomToken(32);
    final exp = DateTime.now().toUtc().add(const Duration(days: sessionDays)).toIso8601String();
    db.exec('INSERT INTO sessions VALUES (?, ?, ?)', [token, userId, exp]);
    db.exec('DELETE FROM sessions WHERE expires_at < ?', [DateTime.now().toUtc().toIso8601String()]);
    return token;
  }

  /// 토큰 → (사용자 id, 관리자 여부). 만료됐거나 없으면 null.
  (int, bool)? userForToken(String token) {
    final r = db.one(
        '''SELECT u.id, u.is_admin FROM sessions s JOIN users u ON u.id = s.user_id
           WHERE s.token = ? AND s.expires_at > ?''',
        [token, DateTime.now().toUtc().toIso8601String()]);
    return r == null ? null : (r['id'] as int, r['is_admin'] == 1);
  }

  void deleteSession(String token) => db.exec('DELETE FROM sessions WHERE token = ?', [token]);

  /// 1인용 시절 데이터(주인 없음)와 개인 설정을 첫 관리자에게 넘긴다.
  void claimLegacyData(int userId, Set<String> userKeys) {
    for (final t in ['characters', 'incomes', 'expenses', 'enhance_log', 'hunts']) {
      db.exec('UPDATE $t SET user_id = ? WHERE user_id IS NULL', [userId]);
    }
    for (final r in db.rows('SELECT key, value FROM settings')) {
      if (userKeys.contains(r['key'])) {
        db.exec('INSERT OR REPLACE INTO user_settings VALUES (?, ?, ?)', [userId, r['key'], r['value']]);
        db.exec('DELETE FROM settings WHERE key = ?', [r['key']]);
      }
    }
  }
}
