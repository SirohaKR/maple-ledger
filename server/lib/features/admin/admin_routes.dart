// 관리 화면 API (관리자만) — 초대 코드, 사용자 비밀번호 초기화·권한·삭제.
import 'dart:isolate';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../core/context.dart';
import '../../core/http.dart';
import '../../core/passwords.dart';
import '../auth/auth_repository.dart';
import 'admin_repository.dart';

class AdminRoutes {
  final AppContext app;
  final AdminRepository admin;
  final AuthRepository users;

  AdminRoutes(this.app)
      : admin = AdminRepository(app.db),
        users = AuthRepository(app.db);

  void register(Router r) {
    r.get('/api/admin', (Request req) {
      req.ctx.requireAdmin();
      return json(_overview());
    });
    r.post('/api/admin/invite', _invite);
    r.put('/api/admin/users/<id>', _editUser);
    r.delete('/api/admin/users/<id>', _deleteUser);
  }

  Map<String, Object?> _overview() => {'users': admin.searchUsers(), 'invite_code': admin.inviteCode()};

  Future<Response> _invite(Request req) async {
    req.ctx.requireAdmin();
    final b = await body(req);
    admin.setInviteCode(strOrNull(b['code']) ?? randomToken(6));
    return json(_overview());
  }

  Future<Response> _editUser(Request req, String id) async {
    final ctx = req.ctx..requireAdmin();
    final userId = pathInt(id), b = await body(req);
    if (b.containsKey('password')) {
      final pw = (b['password'] ?? '').toString();
      if (pw.length < 6) throw ApiError('비밀번호는 6자 이상으로 해 주세요');
      users.setPassword(userId, await Isolate.run(() => hashPassword(pw)));
    }
    if (b.containsKey('is_admin') && userId != ctx.uid) admin.setAdmin(userId, truthy(b['is_admin']));
    return json(_overview());
  }

  Response _deleteUser(Request req, String id) {
    final ctx = req.ctx..requireAdmin();
    final userId = pathInt(id);
    if (userId == ctx.uid) throw ApiError('자기 자신은 지울 수 없어요');
    admin.deleteUser(userId);
    return json(_overview());
  }
}
