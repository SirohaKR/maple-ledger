// 숙제 API — 자동 체크 때 받아 둔 스케줄러 응답으로 캐릭터별 일일·주간 숙제와 보스 현황.
// 따로 테이블이 없다 (자동 체크의 sched_state를 읽기만).
import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../core/context.dart';
import '../../core/http.dart';
import '../sync/sync_repository.dart';

class TodoRoutes {
  final SyncRepository sync;
  TodoRoutes(AppContext app) : sync = SyncRepository(app.db);

  void register(Router r) {
    r.get('/api/todo', _todo);
  }

  Response _todo(Request req) => json([
        for (final c in sync.searchStates(req.ctx.user))
          () {
            final d = c['data'] == null || c['data'] == '' ? {} : jsonDecode(c['data'] as String) as Map;
            return {
              'character': {for (final k in ['id', 'name', 'world', 'job', 'level', 'image']) k: c[k]},
              'fetched_at': c['fetched_at'],
              'daily': d['daily_contents'] ?? [],
              'weekly': d['weekly_contents'] ?? [],
              'bosses': d['boss_contents'] ?? [],
              'boss_count': d['weekly_boss_clear_count'],
              'boss_limit': d['weekly_boss_clear_limit_count'],
            };
          }(),
      ]);
}
