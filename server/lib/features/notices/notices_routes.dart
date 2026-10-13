// 공지 API — 목록·알림, 지금 확인, 알림 확인 처리.
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../core/context.dart';
import '../../core/http.dart';
import 'notices_service.dart';

class NoticesRoutes {
  final NoticesService notices;
  NoticesRoutes(AppContext app) : notices = NoticesService(app);

  void register(Router r) {
    r.get('/api/notices', _list);
    r.post('/api/notices/check', _check);
    r.post('/api/notices/seen', _seen);
  }

  Response _list(Request req) {
    final uid = req.ctx.user;
    final seen = notices.repo.seenBy(uid);
    final rows = [
      for (final r in notices.repo.search()) {...r, 'seen': truthy(r['seen']) || seen.contains(r['id'])},
    ];
    return json({
      'rows': rows,
      'alerts': [for (final r in rows) if (truthy(r['matched']) && r['seen'] != true) r],
      'last_check': notices.settings.get(uid, 'last_notice_check'),
    });
  }

  Future<Response> _check(Request req) async => json({'found': await notices.check(req.ctx.user)});

  Response _seen(Request req) {
    notices.repo.markAllSeen(req.ctx.user);
    return ok();
  }
}
