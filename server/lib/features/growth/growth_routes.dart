// 성장 API — HEXA·심볼·장비, 경험치·전투력 기록, 지난 기록 채우기.
import 'package:shared/shared.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../core/context.dart';
import '../../core/db.dart';
import '../../core/http.dart';
import '../../core/settings_store.dart';
import '../../nexon/api_cache.dart';
import '../../nexon/nexon_client.dart';
import '../characters/characters_repository.dart';
import 'equipment_service.dart';
import 'growth_service.dart';

class GrowthRoutes {
  final AppContext app;
  final CharactersRepository chars;
  final SettingsStore settings;
  final ApiCache cache;
  final EquipmentService equipment;
  final GrowthService growth;

  GrowthRoutes(this.app)
      : chars = CharactersRepository(app.db),
        settings = SettingsStore(app.db),
        cache = ApiCache(app.db),
        equipment = EquipmentService(app.db),
        growth = GrowthService(app.db);

  void register(Router r) {
    r.get('/api/growth/<id>', _growth);
    r.get('/api/growth/<id>/history', _history);
    r.post('/api/growth/<id>/backfill', _backfill);
  }

  /// 넥슨 API로 등록된 내 캐릭터.
  Row _apiChar(int uid, String id) {
    final c = chars.own(uid, id);
    if (c == null || c['ocid'] == null) throw NexonError('넥슨 API로 등록된 캐릭터가 아니에요');
    return c;
  }

  Future<Response> _growth(Request req, String id) async {
    final uid = req.ctx.user;
    final c = _apiChar(uid, id);
    final ocid = c['ocid'] as String;
    final nexon = app.nexonFor(settings.apiKey(uid));
    final ttl = req.url.queryParameters['refresh'] == '1' ? 0 : 1800;
    final eq = await equipment.equipmentFor(nexon, ocid, ttl: ttl);
    final Map hexa = await cache.cached('hexa:$ocid', ttl, () => nexon.hexamatrix(ocid));
    final Map sk = await cache.cached('skill6:$ocid', ttl, () => nexon.skills(ocid, '6'));
    final Map sym = await cache.cached('symbol:$ocid', ttl, () => nexon.symbols(ocid));

    final icons = {for (final s in (sk['character_skill'] as List? ?? [])) s['skill_name']: s['skill_icon']};
    final fragPrice = toInt(settings.get(uid, 'fragment_price'));
    final cores = <Map<String, Object?>>[];
    for (final core in (hexa['character_hexa_core_equipment'] as List? ?? [])) {
      final linked = [for (final x in (core['linked_skill'] as List? ?? [])) x['hexa_skill_id']];
      final icon = icons[core['hexa_core_name']] ??
          linked.map((n) => icons[n]).firstWhere((i) => i != null && i != '', orElse: () => null);
      cores.add({
        'name': core['hexa_core_name'],
        'type': core['hexa_core_type'],
        'level': core['hexa_core_level'] ?? 0,
        'icon': icon,
        'linked': linked,
        'remaining': hexaRemaining(core['hexa_core_type'] as String?, core['hexa_core_level']),
      });
    }
    int sumRemaining(String k) =>
        cores.fold(0, (a, x) => a + (x['remaining'] == null ? 0 : (x['remaining'] as Map)[k] as int));
    final remFrag = sumRemaining('fragments');

    return json({
      'character': c,
      'hexa': {
        'cores': cores,
        'remaining_erda': sumRemaining('erda'),
        'remaining_fragments': remFrag,
        'remaining_meso': remFrag * fragPrice,
        'fragment_price': fragPrice,
      },
      'symbols': [
        for (final x in (sym['symbol'] as List? ?? []))
          {
            'name': x['symbol_name'], 'icon': x['symbol_icon'], 'level': x['symbol_level'],
            'force': x['symbol_force'], 'growth': x['symbol_growth_count'], 'require': x['symbol_require_growth_count'],
          },
      ],
      'equipment': [
        for (final x in (eq['item_equipment'] as List? ?? []))
          {
            'slot': x['item_equipment_slot'], 'part': x['item_equipment_part'], 'name': x['item_name'],
            'icon': x['item_icon'], 'star': x['starforce'],
            'grade': x['potential_option_grade'], 'add_grade': x['additional_potential_option_grade'],
            'level': x['item_base_option'] is Map ? x['item_base_option']['base_equipment_level'] : null,
            'detail': itemDetail(x as Map),
          },
      ],
    });
  }

  /// 경험치·전투력 기록 + 하루 경험치 증가량(%) + 그날 사냥 시간.
  Response _history(Request req, String id) {
    final c = chars.own(req.ctx.user, id) ?? (throw ApiError('내 캐릭터가 아니에요', 404));
    final cid = c['id'] as int;
    final days = toInt(req.url.queryParameters['days'], 60).clamp(7, 365);
    final since = isoDate(todayKst().subtract(Duration(days: days)));
    final rows = growth.repo.searchDaily(cid, since);
    final hunts = growth.repo.huntMinutesByDate(cid, since);
    Row? prev;
    for (final r in rows) {
      r['gain'] = null;
      // 하루 경험치 증가량(%) = 레벨 차이 × 100 + 경험치 % 차이
      if (prev != null && r['level'] != null && prev['level'] != null && r['exp_rate'] != null) {
        final g = ((r['level'] as int) - (prev['level'] as int)) * 100 +
            ((r['exp_rate'] as num) - ((prev['exp_rate'] as num?) ?? 0));
        r['gain'] = roundHalfEven(g * 1000) / 1000;
      }
      r['hunt_minutes'] = hunts[r['date']];
      prev = r;
    }
    return json(rows);
  }

  /// 지난 N일 경험치·전투력을 한 번에 채운다 (하루당 API 2회).
  Future<Response> _backfill(Request req, String id) async {
    final uid = req.ctx.user;
    final c = _apiChar(uid, id);
    final cid = c['id'] as int;
    final b = await body(req);
    final days = toInt(b['days'] ?? 30, 30).clamp(1, 60);
    final have = growth.repo.dailyDates(cid);
    final nexon = app.nexonFor(settings.apiKey(uid));
    final t = todayKst();
    var added = 0;
    for (var i = days; i > 0; i--) {
      final d = t.subtract(Duration(days: i));
      if (have.contains(isoDate(d)) || d.isBefore(DateTime.utc(2023, 12, 21))) continue;
      await growth.snapshot(nexon, cid, c['ocid'] as String, isoDate(d));
      added++;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    return json({'added': added});
  }
}
