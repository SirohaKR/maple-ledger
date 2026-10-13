// 통계 API — 최근 N주 수익(보스·사냥·기타)과 지출, 월별 보스, 캐릭터별 합계.
// 따로 테이블이 없다 (각 기능의 저장소를 모아서 계산).
import 'package:shared/shared.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../core/context.dart';
import '../../core/http.dart';
import '../../core/settings_store.dart';
import '../characters/characters_repository.dart';
import '../hunts/hunts_repository.dart';
import '../incomes/incomes_repository.dart';
import '../spend/enhance_repository.dart';
import '../spend/expenses_repository.dart';
import '../week/week_service.dart';

class StatsRoutes {
  final WeekService week;
  final HuntsRepository hunts;
  final IncomesRepository incomes;
  final ExpensesRepository expenses;
  final EnhanceRepository enhance;
  final CharactersRepository chars;
  final SettingsStore settings;

  StatsRoutes(AppContext app)
      : week = WeekService(app.db),
        hunts = HuntsRepository(app.db),
        incomes = IncomesRepository(app.db),
        expenses = ExpensesRepository(app.db),
        enhance = EnhanceRepository(app.db),
        chars = CharactersRepository(app.db),
        settings = SettingsStore(app.db);

  void register(Router r) {
    r.get('/api/stats', _stats);
  }

  String _weekOf(Object? date) => isoDate(weekStart(parseDate(date) ?? todayKst()));

  Response _stats(Request req) {
    final uid = req.ctx.user;
    final n = toInt(req.url.queryParameters['weeks'], 12).clamp(1, 52);
    final cur = weekStart(todayKst());
    final weeks = [for (var i = n - 1; i >= 0; i--) isoDate(cur.subtract(Duration(days: 7 * i)))];

    void add(Map<Object?, int> m, Object? k, int v) => m[k] = (m[k] ?? 0) + v;

    final huntByWeek = <Object?, int>{}, huntByChar = <Object?, int>{};
    var huntMinutes = 0, huntMeso = 0;
    for (final h in hunts.searchDone(uid, weeks.first)) {
      final total = huntParts(h).total;
      add(huntByWeek, _weekOf(h['date']), total);
      add(huntByChar, h['character_id'], total);
      if (truthy(h['minutes'])) {
        huntMinutes += h['minutes'] as int;
        huntMeso += (h['meso'] as int?) ?? 0;
      }
    }

    final etcByWeek = <Object?, int>{}, etcByChar = <Object?, int>{};
    for (final r in incomes.searchSold(uid, weeks.first)) {
      add(etcByWeek, _weekOf(r['date']), r['amount'] as int);
      add(etcByChar, r['character_id'], r['amount'] as int);
    }

    // 지출 = 강화 기록 추정 비용 + 직접 넣은 지출 (장부 시작일부터)
    final nameToId = chars.idsByName(uid);
    final ledgerStart = settings.ledgerStart(uid);
    final since = weeks.first.compareTo(ledgerStart) >= 0 ? weeks.first : ledgerStart;
    final spendByWeek = <Object?, int>{}, spendByChar = <Object?, int>{};
    final spendRows = [
      for (final r in expenses.searchSince(uid, since)) (r['character_id'], r['date'], r['amount'] as int?),
      for (final r in enhance.searchCosts(uid, since)) (nameToId[r['character_name']], r['date'], r['cost'] as int?),
    ];
    for (final (cid, d, amt) in spendRows) {
      add(spendByWeek, _weekOf(d), amt ?? 0);
      add(spendByChar, cid, amt ?? 0);
    }

    final series = <Map<String, Object?>>[];
    final bossByChar = <Object?, int>{};
    for (final wk in weeks) {
      final w = week.computeWeek(uid, wk);
      (w['chars'] as Map<String, Object?>).forEach((cid, c) => add(bossByChar, int.parse(cid), (c as Map)['income'] as int));
      series.add({
        'week': wk,
        'boss': w['total'],
        'hunt': huntByWeek[wk] ?? 0,
        'etc': etcByWeek[wk] ?? 0,
        'spend': spendByWeek[wk] ?? 0,
      });
    }

    final months = {for (final wk in weeks) wk.substring(0, 7)}.toList()..sort();
    final monthly = [for (final m in months) {'month': m, 'total': week.computeMonth(uid, m)['total']}];

    final names = {for (final c in chars.search(uid)) c['id']: c['name']};
    final ids = {...bossByChar.keys, ...huntByChar.keys, ...etcByChar.keys, ...spendByChar.keys};
    final perChar = [
      for (final cid in ids)
        {
          'character_id': cid,
          'name': names[cid] ?? '(삭제됨/미지정)',
          'boss': bossByChar[cid] ?? 0,
          'hunt': huntByChar[cid] ?? 0,
          'etc': etcByChar[cid] ?? 0,
          'spend': spendByChar[cid] ?? 0,
        },
    ];
    int earned(Map r) => (r['boss'] as int) + (r['hunt'] as int) + (r['etc'] as int);
    perChar.sort((a, b) => earned(b).compareTo(earned(a)));

    final pending = incomes.pending(uid);
    return json({
      'series': series,
      'monthly': monthly,
      'per_char': perChar,
      'hunt_minutes': huntMinutes,
      'hunt_per_hour': huntMinutes > 0 ? roundHalfEven(huntMeso / huntMinutes * 60) : 0,
      'pending': {'count': pending['count'], 'amount': pending['amount']},
      'ledger_start': ledgerStart,
    });
  }
}
