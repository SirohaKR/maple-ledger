// 로그인 API — 내 정보, 가입(초대 코드), 로그인, 로그아웃, 비밀번호 바꾸기.
import 'dart:isolate';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../core/context.dart';
import '../../core/http.dart';
import '../../core/passwords.dart';
import '../../core/settings_store.dart';
import 'auth_middleware.dart';
import 'auth_repository.dart';

class AuthRoutes {
  final AppContext app;
  final AuthRepository users;
  final _fails = <String, List<DateTime>>{}; // ip → 로그인 실패 시각들 (무차별 대입 방지)

  AuthRoutes(this.app) : users = AuthRepository(app.db);

  void register(Router r) {
    r.get('/api/auth/me', _me);
    r.post('/api/auth/signup', _signup);
    r.post('/api/auth/login', _login);
    r.post('/api/auth/logout', _logout);
    r.put('/api/account/password', _password);
  }

  // 비밀번호 계산은 0.5초쯤 걸려서 다른 요청이 멈추지 않게 따로 돌린다
  Future<String> _hash(String pw) => Isolate.run(() => hashPassword(pw));
  Future<bool> _check(String stored, String pw) => Isolate.run(() => checkPassword(stored, pw));

  Response _withSession(Map<String, Object?> data, int userId) {
    final token = users.createSession(userId);
    return json(data).change(headers: {
      'set-cookie': '$sessionCookie=$token; Path=/; HttpOnly; SameSite=Lax; Max-Age=${sessionDays * 86400}',
    });
  }

  Response _me(Request req) {
    final uid = req.ctx.uid;
    if (uid == null) return json({'user': null, 'first_user': users.countUsers() == 0}, status: 401);
    return json({'user': users.me(uid), 'first_user': false});
  }

  Future<Response> _signup(Request req) async {
    final b = await body(req);
    final name = (b['username'] ?? '').toString().trim(), pw = (b['password'] ?? '').toString();
    if (name.length < 2 || name.length > 20 || pw.length < 6) throw ApiError('아이디는 2~20자, 비밀번호는 6자 이상으로 해 주세요');
    final first = users.countUsers() == 0;
    if (!first) {
      final code = SettingsStore(app.db).global('invite_code');
      if (code == null || code.isEmpty || (b['invite'] ?? '').toString().trim() != code) {
        throw ApiError('초대 코드가 맞지 않아요. 관리자에게 받아 주세요', 403);
      }
    }
    final id = users.createUser(name, await _hash(pw), admin: first) ?? (throw ApiError('이미 있는 아이디예요'));
    if (first) {
      users.claimLegacyData(id, userKeys);
      app.db.exec("INSERT OR REPLACE INTO settings VALUES ('invite_code', ?)", [randomToken(6)]);
    }
    return _withSession({'user': users.me(id)}, id);
  }

  Future<Response> _login(Request req) async {
    final ip = (req.context['shelf.io.connection_info'] as dynamic)?.remoteAddress?.address?.toString() ?? '?';
    final now = DateTime.now();
    final fails = (_fails[ip] ?? []).where((t) => now.difference(t).inMinutes < 10).toList();
    _fails[ip] = fails;
    if (fails.length >= 10) throw ApiError('로그인 실패가 너무 많아요. 10분 뒤에 다시 해 주세요', 429);
    final b = await body(req);
    final u = users.findByName((b['username'] ?? '').toString().trim());
    if (u == null || !await _check(u['pw_hash'] as String, (b['password'] ?? '').toString())) {
      fails.add(now);
      throw ApiError('아이디나 비밀번호가 맞지 않아요', 401);
    }
    return _withSession({'user': users.me(u['id'] as int)}, u['id'] as int);
  }

  Response _logout(Request req) {
    final token = cookieValue(req, sessionCookie);
    if (token != null) users.deleteSession(token);
    return ok().change(headers: {'set-cookie': '$sessionCookie=; Path=/; HttpOnly; SameSite=Lax; Max-Age=0'});
  }

  Future<Response> _password(Request req) async {
    final uid = req.ctx.user, b = await body(req);
    final u = users.findUser(uid)!;
    if (!await _check(u['pw_hash'] as String, (b['old'] ?? '').toString())) throw ApiError('지금 비밀번호가 맞지 않아요');
    final nw = (b['new'] ?? '').toString();
    if (nw.length < 6) throw ApiError('새 비밀번호는 6자 이상으로 해 주세요');
    users.setPassword(uid, await _hash(nw));
    return ok();
  }
}
