// 보스 기록 API — 주간·월간 수익, 클리어 체크, 프리셋대로 체크.
import 'package:shared/shared.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../core/context.dart';
import '../../core/http.dart';
import '../characters/characters_repository.dart';
import 'week_service.dart';

class WeekRoutes {
  final AppContext app;
  final WeekService week;
  final CharactersRepository chars;

  WeekRoutes(this.app)
      : week = WeekService(app.db),
        chars = CharactersRepository(app.db);

  void register(Router r) {
    r.get('/api/week', _week);
    r.get('/api/month', _month);
    r.put('/api/clears', _setClear);
    r.post('/api/week/fill', _fill);
  }

  Response _week(Request req) {
    final d = parseDate(req.url.queryParameters['week']) ?? todayKst();
    final ws = weekStart(d);
    final res = week.computeWeek(req.ctx.user, isoDate(ws));
    res['prev'] = isoDate(ws.subtract(const Duration(days: 7)));
    res['next'] = isoDate(ws.add(const Duration(days: 7)));
    res['end'] = isoDate(ws.add(const Duration(days: 6)));
    res['is_current'] = ws == weekStart(todayKst());
    res['prices'] = {for (final e in week.bosses.pricesOn(isoDate(ws)).entries) '${e.key}': e.value};
    return json(res);
  }

  Response _month(Request req) {
    final q = req.url.queryParameters['month'];
    final month = (q == null || q.isEmpty ? monthOf(todayKst()) : q).substring(0, 7);
    return json({
      ...week.computeMonth(req.ctx.user, month),
      'prices': {for (final e in week.bosses.pricesOn('$month-01').entries) '${e.key}': e.value},
    });
  }

  Future<Response> _setClear(Request req) async {
    final uid = req.ctx.user, b = await body(req);
    final cid = toInt(b['character_id']), bid = toInt(b['boss_id']), period = '${b['period']}';
    if (chars.own(uid, cid) == null) throw ApiError('내 캐릭터가 아니에요', 404);
    final count = b.containsKey('count') ? toInt(b['count']) : 1;
    if (count <= 0) {
      week.clears.delete(cid, bid, period);
    } else {
      final party = toInt(b['party_size'], 1);
      week.clears.upsertManual(cid, bid, period, count, party < 1 ? 1 : party);
    }
    return ok();
  }

  /// 프리셋 그대로 이번 주 클리어 체크 (이미 체크한 건 그대로 둔다).
  Future<Response> _fill(Request req) async {
    final b = await body(req);
    final ws = weekStart(parseDate(b['week']) ?? todayKst());
    week.clears.fillFromPreset(req.ctx.user, isoDate(ws), characterId: truthy(b['character_id']) ? toInt(b['character_id']) : null);
    return ok();
  }
}
