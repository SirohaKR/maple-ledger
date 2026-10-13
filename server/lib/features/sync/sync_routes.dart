// 자동 체크 API — 지금 바로 보스 자동 체크.
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../core/context.dart';
import '../../core/http.dart';
import 'sync_service.dart';

class SyncRoutes {
  final SyncService sync;
  SyncRoutes(AppContext app) : sync = SyncService(app);

  void register(Router r) {
    r.post('/api/sync', _sync);
  }

  Future<Response> _sync(Request req) async {
    final res = await sync.syncOnce(req.ctx.user);
    if (res == null) throw ApiError('이미 동기화 중이에요', 409);
    return json(res);
  }
}
