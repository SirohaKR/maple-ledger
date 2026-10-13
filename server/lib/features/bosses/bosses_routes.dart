// 보스 가격표 API — 목록은 모두, 수정은 관리자만.
import 'package:shared/shared.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../core/context.dart';
import '../../core/http.dart';
import 'bosses_repository.dart';

class BossesRoutes {
  final AppContext app;
  final BossesRepository bosses;
  BossesRoutes(this.app) : bosses = BossesRepository(app.db);

  void register(Router r) {
    r.get('/api/bosses', _list);
    r.post('/api/bosses', _add);
    r.put('/api/bosses/<id>', _edit);
    r.delete('/api/bosses/<id>', _delete);
    r.post('/api/bosses/<id>/prices', _addPrice);
    r.delete('/api/prices/<id>', _deletePrice);
  }

  Response _list(Request req) {
    final day = req.url.queryParameters['date'] ?? isoDate(todayKst());
    final current = bosses.pricesOn(day);
    final history = bosses.priceHistory();
    return json([
      for (final b in bosses.search()) {...b, 'price': current[b['id']], 'history': history[b['id']] ?? []},
    ]);
  }

  Future<Response> _add(Request req) async {
    req.ctx.requireAdmin();
    final b = await body(req);
    final name = strOrNull(b['name']), diff = strOrNull(b['difficulty']), cycle = b['cycle'];
    if (name == null || diff == null || !['daily', 'weekly', 'monthly'].contains(cycle)) {
      throw ApiError('이름, 난이도, 주기를 확인해 주세요');
    }
    if (bosses.exists(name, diff, cycle as String)) throw ApiError('이미 있는 보스/난이도예요');
    final id = bosses.insert(name, diff, cycle, toInt(b['max_party'], 6) == 0 ? 6 : toInt(b['max_party'], 6));
    bosses.upsertPrice(id, toInt(b['price']), strOrNull(b['effective_from']) ?? '2000-01-01');
    return json({'id': id});
  }

  Future<Response> _edit(Request req, String id) async {
    req.ctx.requireAdmin();
    final b = await body(req);
    const allowed = ['name', 'difficulty', 'cycle', 'max_party', 'hidden', 'sort', 'api_name', 'image_url'];
    final fields = {for (final k in allowed) if (b.containsKey(k)) k: b[k]};
    for (final k in ['api_name', 'image_url']) {
      if (fields.containsKey(k)) fields[k] = strOrNull(fields[k]);
    }
    if (fields.isEmpty) throw ApiError('바꿀 항목이 없어요');
    bosses.update(pathInt(id), fields);
    return ok();
  }

  Response _delete(Request req, String id) {
    req.ctx.requireAdmin();
    final used = bosses.countClears(pathInt(id));
    if (used > 0) throw ApiError('기록이 $used개 있는 보스예요. 삭제 대신 숨기기를 써 주세요');
    bosses.delete(pathInt(id));
    return ok();
  }

  Future<Response> _addPrice(Request req, String id) async {
    req.ctx.requireAdmin();
    final b = await body(req);
    final eff = parseDate(b['effective_from']);
    final price = toIntOrNull(b['price']);
    if (eff == null || price == null) throw ApiError('가격과 적용일을 넣어 주세요');
    bosses.upsertPrice(pathInt(id), price, isoDate(eff));
    return ok();
  }

  Response _deletePrice(Request req, String id) {
    req.ctx.requireAdmin();
    final row = bosses.findPrice(pathInt(id)) ?? (throw ApiError('없는 가격이에요', 404));
    if (bosses.countPrices(row['boss_id'] as int) <= 1) throw ApiError('가격이 하나뿐이라 지울 수 없어요');
    bosses.deletePrice(pathInt(id));
    return ok();
  }
}
