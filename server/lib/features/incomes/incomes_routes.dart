// 기타 수익 API — 목록, 개인 시세, 추가·수정·삭제.
import 'package:shared/shared.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../core/context.dart';
import '../../core/http.dart';
import '../characters/characters_repository.dart';
import 'incomes_repository.dart';

const _kinds = {'drop', 'fragment', 'side', 'etc'};

class IncomesRoutes {
  final IncomesRepository incomes;
  final CharactersRepository chars;

  IncomesRoutes(AppContext app)
      : incomes = IncomesRepository(app.db),
        chars = CharactersRepository(app.db);

  void register(Router r) {
    r.get('/api/incomes', _list);
    r.get('/api/incomes/prices', _prices);
    r.post('/api/incomes', _add);
    r.put('/api/incomes/<id>', _edit);
    r.delete('/api/incomes/<id>', _delete);
  }

  /// 화면에서 온 값 정리 + 실수령액 계산.
  Map<String, Object?> _clean(int uid, Map<String, Object?> b) {
    final kind = _kinds.contains(b['kind']) ? b['kind'] as String : 'etc';
    int atLeast1(Object? v) {
      final n = truthy(v) ? toInt(v) : 1;
      return n < 1 ? 1 : n;
    }

    final r = <String, Object?>{
      'date': isoDate(parseDate(b['date']) ?? todayKst()),
      'character_id': chars.own(uid, b['character_id']) != null ? toInt(b['character_id']) : null,
      'kind': kind,
      'boss_id': truthy(b['boss_id']) && kind == 'drop' ? toInt(b['boss_id']) : null,
      'title': strOrNull(b['title']),
      'qty': atLeast1(b['qty']),
      'gross': toInt(b['gross']),
      'fee_rate': toDoubleOrNull(b['fee_rate']) ?? 0.0,
      'party_size': atLeast1(b['party_size']),
      'split': b['split'] == 'ratio' ? 'ratio' : 'equal',
      'role': b['role'] == 'member' ? 'member' : 'leader',
      'leader_ratio': truthy(b['leader_ratio']) ? toInt(b['leader_ratio']) : 1,
      'member_ratio': truthy(b['member_ratio']) ? toInt(b['member_ratio']) : 1,
      'sold': !b.containsKey('sold') || truthy(b['sold']) ? 1 : 0,
      'note': strOrNull(b['note']),
    };
    r['amount'] = incomeAmount(r);
    return r;
  }

  Response _list(Request req) {
    final q = req.url.queryParameters;
    return json(incomes.search(req.ctx.user, from: strOrNull(q['from']), to: strOrNull(q['to']), kind: strOrNull(q['kind'])));
  }

  Response _prices(Request req) => json([
        for (final r in incomes.prices(req.ctx.user))
          {'title': r['title'], 'n': r['n'], 'avg': (r['avg'] as num).toInt(), 'last': ((r['last'] as num?) ?? 0).toInt()},
      ]);

  Future<Response> _add(Request req) async {
    final uid = req.ctx.user;
    final r = {..._clean(uid, await body(req)), 'user_id': uid};
    return json({'id': incomes.insert(r), 'amount': r['amount']});
  }

  Future<Response> _edit(Request req, String id) async {
    final uid = req.ctx.user;
    final r = _clean(uid, await body(req));
    incomes.update(uid, pathInt(id), r);
    return json({'ok': true, 'amount': r['amount']});
  }

  Response _delete(Request req, String id) {
    incomes.delete(req.ctx.user, pathInt(id));
    return ok();
  }
}
