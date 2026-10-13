// 요청마다 로그인한 사용자를 찾아 둔다. /api/ 는 로그인이 필요 (가입·로그인 API(/api/auth/)는 제외).
import 'package:shelf/shelf.dart';

import '../../core/context.dart';
import '../../core/http.dart';
import 'auth_repository.dart';

const sessionCookie = 'ml_session';

String? cookieValue(Request req, String name) {
  final header = req.headers['cookie'];
  if (header == null) return null;
  for (final part in header.split(';')) {
    final i = part.indexOf('=');
    if (i > 0 && part.substring(0, i).trim() == name) return part.substring(i + 1).trim();
  }
  return null;
}

Middleware authMiddleware(AppContext app) {
  final repo = AuthRepository(app.db);
  return (inner) => (req) async {
        var ctx = const Ctx(null, false);
        final token = cookieValue(req, sessionCookie);
        if (token != null) {
          final u = repo.userForToken(token);
          if (u != null) ctx = Ctx(u.$1, u.$2);
        }
        final path = '/${req.url.path}';
        if (path.startsWith('/api/') && !path.startsWith('/api/auth/') && ctx.uid == null) {
          return json({'error': '로그인이 필요해요'}, status: 401);
        }
        return inner(req.change(context: {...req.context, 'ctx': ctx}));
      };
}
