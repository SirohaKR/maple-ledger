// 결정석 수익 계산 — 주간(일간+주간 보스, 판매 한도 적용)과 월간(검은 마법사).
import 'package:shared/shared.dart';

import '../../core/db.dart';
import '../bosses/bosses_repository.dart';
import '../settings/rules_repository.dart';
import 'clears_repository.dart';

class WeekService {
  final ClearsRepository clears;
  final BossesRepository bosses;
  final RulesRepository rules;

  WeekService(Db db)
      : clears = ClearsRepository(db),
        bosses = BossesRepository(db),
        rules = RulesRepository(db);

  /// 주간 결정석 수익. 캐릭터/월드 판매 한도 안에서 비싼 결정석부터 팔린다고 계산.
  Map<String, Object?> computeWeek(int uid, String week) {
    final rule = rules.ruleOn(week);
    final limit = rule['char_limit'] as int, worldLimit = rule['world_limit'] as int;
    final dailyInLimit = rule['daily_in_limit'] != 0;
    final prices = bosses.pricesOn(week);

    final items = <Row>[];
    for (final r in clears.searchWeek(uid, week)) {
      final price = prices[r['boss_id']] ?? 0;
      final party = (r['party_size'] as int) < 1 ? 1 : r['party_size'] as int;
      items.add({...r, 'price': price, 'share': price ~/ party, 'sold': 0, 'income': 0});
    }
    final worlds = applyCrystalLimits(items, charLimit: limit, worldLimit: worldLimit, dailyInLimit: dailyInLimit);

    final chars = <String, Object?>{};
    final byChar = <int, List<Row>>{};
    for (final it in items) {
      byChar.putIfAbsent(it['character_id'] as int, () => []).add(it);
    }
    var total = 0;
    byChar.forEach((cid, list) {
      final income = list.fold<int>(0, (a, i) => a + (i['income'] as int));
      total += income;
      chars['$cid'] = {
        'clears': list,
        'income': income,
        'sold': list.where((i) => i['cycle'] == 'weekly' || dailyInLimit).fold<int>(0, (a, i) => a + (i['sold'] as int)),
        'crystals': list.fold<int>(0, (a, i) => a + (i['count'] as int)),
      };
    });
    return {'week': week, 'limit': limit, 'world_limit': worldLimit, 'worlds': worlds, 'chars': chars, 'total': total};
  }

  /// 월간 보스 수익 (그 달 1일 기준 가격, 한도 없음).
  Map<String, Object?> computeMonth(int uid, String month) {
    final prices = bosses.pricesOn('$month-01');
    final items = <Row>[];
    for (final r in clears.searchMonth(uid, month)) {
      final price = prices[r['boss_id']] ?? 0;
      final party = (r['party_size'] as int) < 1 ? 1 : r['party_size'] as int;
      final share = price ~/ party;
      items.add({...r, 'price': price, 'share': share, 'sold': r['count'], 'income': share * (r['count'] as int)});
    }
    return {'month': month, 'clears': items, 'total': items.fold<int>(0, (a, i) => a + (i['income'] as int))};
  }
}
