// 지출 API — 강화 기록(불러오기·목록·비용 고치기), 직접 넣는 지출.
import 'package:shared/shared.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../core/context.dart';
import '../../core/http.dart';
import '../characters/characters_repository.dart';
import 'enhance_service.dart';
import 'expenses_repository.dart';

class SpendRoutes {
  final EnhanceService enhance;
  final ExpensesRepository expenses;
  final CharactersRepository chars;

  SpendRoutes(AppContext app)
      : enhance = EnhanceService(app),
        expenses = ExpensesRepository(app.db),
        chars = CharactersRepository(app.db);

  void register(Router r) {
    r.post('/api/enhance/sync', _sync);
    r.get('/api/enhance', _enhance);
    r.put('/api/enhance/<id>', _editEnhance);
    r.get('/api/expenses', _expenses);
    r.post('/api/expenses', _addExpense);
    r.put('/api/expenses/<id>', _editExpense);
    r.delete('/api/expenses/<id>', _deleteExpense);
  }

  Future<Response> _sync(Request req) async {
    final b = await body(req);
    final res = await enhance.syncOnce(req.ctx.user, days: truthy(b['days']) ? toInt(b['days']) : null);
    if (res == null) throw ApiError('이미 불러오는 중이에요', 409);
    return json(res);
  }

  Response _enhance(Request req) {
    final uid = req.ctx.user, q = req.url.queryParameters;
    final from = strOrNull(q['from']) ?? isoDate(todayKst().subtract(const Duration(days: 30)));
    final to = strOrNull(q['to']) ?? isoDate(todayKst());
    final rows = enhance.repo.search(uid, from, to, strOrNull(q['character']));
    final names = {for (final r in rows) if (truthy(r['target_item'])) r['target_item'] as String};
    return json({
      'rows': rows,
      'characters': enhance.repo.perCharacter(uid, from, to),
      'items': enhance.equipment.repo.itemDetails(names),
      'last_sync': enhance.settings.get(uid, 'last_enhance_sync'),
    });
  }

  /// 비용 직접 고치기, 또는 reset으로 추정 비용으로 되돌리기.
  Future<Response> _editEnhance(Request req, String id) async {
    final uid = req.ctx.user, b = await body(req);
    final eid = Uri.decodeComponent(id);
    if (truthy(b['reset'])) {
      enhance.repo.resetCost(uid, eid);
      enhance.price(uid);
    } else {
      enhance.repo.setManualCost(uid, eid, toInt(b['cost']));
    }
    return ok();
  }

  Response _expenses(Request req) =>
      json(expenses.search(req.ctx.user, strOrNull(req.url.queryParameters['from']) ?? '0000-00-00'));

  Map<String, Object?> _clean(int uid, Map<String, Object?> b) => {
        'date': isoDate(parseDate(b['date']) ?? todayKst()),
        'character_id': chars.own(uid, b['character_id']) != null ? toInt(b['character_id']) : null,
        'category': strOrNull(b['category']) ?? '기타',
        'amount': toInt(b['amount']),
        'note': strOrNull(b['note']),
      };

  Future<Response> _addExpense(Request req) async {
    final uid = req.ctx.user;
    return json({'id': expenses.insert({..._clean(uid, await body(req)), 'user_id': uid})});
  }

  Future<Response> _editExpense(Request req, String id) async {
    final uid = req.ctx.user;
    expenses.update(uid, pathInt(id), _clean(uid, await body(req)));
    return ok();
  }

  Response _deleteExpense(Request req, String id) {
    expenses.delete(req.ctx.user, pathInt(id));
    return ok();
  }
}
