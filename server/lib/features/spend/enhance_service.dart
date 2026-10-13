// 강화 기록 불러오기 + 추정 비용 계산.
import 'dart:convert';

import 'package:shared/shared.dart';

import '../../core/context.dart';
import '../../core/http.dart';
import '../../core/settings_store.dart';
import '../../nexon/api_cache.dart';
import '../../nexon/nexon_client.dart';
import '../characters/characters_repository.dart';
import '../growth/equipment_service.dart';
import 'enhance_repository.dart';

/// '파괴 방지 적용' / '파괴 방지 미적용' / '슈페리얼 장비 아님' / true 같은 값을 참·거짓으로.
bool flagText(Object? v, [String word = '적용']) {
  final s = (v ?? '').toString().trim();
  final low = s.toLowerCase();
  if (const {'true', 'y', '1'}.contains(low)) return true;
  if (s.isEmpty || const ['미적용', '아님', '없음', '미사용'].any(s.contains) || const {'false', 'n', '0'}.contains(low)) {
    return false;
  }
  return s.contains(word);
}

class EnhanceService {
  /// 지금 강화 기록을 불러오는 중인 사람.
  static final _running = <int>{};

  final AppContext app;
  final EnhanceRepository repo;
  final CharactersRepository chars;
  final SettingsStore settings;
  final EquipmentService equipment;
  final ApiCache cache;

  EnhanceService(this.app)
      : repo = EnhanceRepository(app.db),
        chars = CharactersRepository(app.db),
        settings = SettingsStore(app.db),
        equipment = EquipmentService(app.db),
        cache = ApiCache(app.db);

  /// 넥슨 기록 한 건 저장 — 새로 들어갔으면 1.
  int store(int uid, String kind, Map<String, dynamic> r) {
    final at = '${r['date_create'] ?? ''}';
    final row = <String, Object?>{
      'id': '$kind:${r['id']}',
      'user_id': uid,
      'kind': kind,
      'date': at.length >= 10 ? at.substring(0, 10) : at,
      'at': (at.length >= 19 ? at.substring(0, 19) : at).replaceAll('T', ' '),
      'character_name': r['character_name'],
      'target_item': r['target_item'],
      'item_level': r['item_level'],
      'before_star': null,
      'after_star': null,
      'result': r['item_upgrade_result'],
      'grade': null,
      'sub': null,
      'destroy_defence': 0,
    };
    if (kind == 'starforce') {
      row['before_star'] = r['before_starforce_count'];
      row['after_star'] = r['after_starforce_count'];
      row['destroy_defence'] = flagText(r['destroy_defence']) ? 1 : 0;
      final notes = [
        if (truthy(r['upgrade_item'])) '${r['upgrade_item']}',
        if (flagText(r['superior_item_flag'], '슈페리얼')) '슈페리얼',
        if (flagText(r['chance_time'], '찬스')) '찬스 타임',
      ];
      row['sub'] = notes.isEmpty ? null : notes.join(', ');
    } else {
      final additional = '${r['potential_type'] ?? ''}'.contains('에디셔널');
      row['sub'] = kind == 'potential' ? r['potential_type'] : r['cube_type'];
      row['grade'] = additional ? r['additional_potential_option_grade'] : r['potential_option_grade'];
    }
    row['raw'] = jsonEncode(r);
    return repo.insert(row);
  }

  /// 비용이 비어 있는 기록에 추정 비용을 채운다 (직접 고친 비용은 건드리지 않음).
  void price(int uid) {
    final discount = double.tryParse(settings.get(uid, 'starforce_discount') ?? '') ?? 0;
    final levels = equipment.repo.itemLevels();
    for (final r in repo.searchUnpriced(uid)) {
      int? cost;
      final sub = r['sub'] as String?;
      if (r['kind'] == 'starforce') {
        if (sub == null || sub.isEmpty || sub == '찬스 타임') {
          // 주문서·슈페리얼은 메소 공식이 달라서 제외
          final raw = jsonDecode((r['raw'] as String?) ?? '{}') as Map;
          cost = starforceCost(levels[r['target_item']], r['before_star'] as int?,
              destroyDefence: r['destroy_defence'] != 0, mvpDiscount: discount, events: raw['starforce_event_list'] as List?);
        }
      } else if (r['kind'] == 'potential') {
        final upgraded = ['상승', '성공'].any('${r['result'] ?? ''}'.contains);
        cost = potentialCost(r['item_level'] as int?, gradeBefore(r['grade'] as String?, upgraded),
            additional: (sub ?? '').contains('에디셔널'));
      }
      if (cost != null) repo.setCost(r['id'] as String, cost);
    }
  }

  /// 이미 불러오는 중이면 null.
  Future<Map<String, Object?>?> syncOnce(int uid, {int? days}) async {
    if (!_running.add(uid)) return null;
    try {
      return await sync(uid, days: days);
    } finally {
      _running.remove(uid);
    }
  }

  /// 최근 N일 강화 기록을 받아온다 (지난 날짜는 한 번만, 오늘은 매번).
  Future<Map<String, Object?>> sync(int uid, {int? days}) async {
    final key = settings.apiKey(uid);
    if (key.isEmpty) throw NexonError('넥슨 API 키가 없어요');
    final nexon = app.nexonFor(key);
    final t = todayKst();
    final setting = toInt(settings.get(uid, 'enhance_backfill_days'));
    final n = days ?? (setting == 0 ? 30 : setting);
    final start = t.subtract(Duration(days: (n < 1 ? 1 : n) - 1));
    final done = repo.doneDays(uid);
    var added = 0;
    final errors = <String>[];
    for (final kind in ['starforce', 'potential', 'cube']) {
      for (var d = start; !d.isAfter(t); d = d.add(const Duration(days: 1))) {
        final ds = isoDate(d);
        if (done.contains((kind, ds)) && d != t) continue;
        try {
          for (final r in await nexon.history(kind, ds)) {
            added += store(uid, kind, r);
          }
          if (d.isBefore(t)) repo.markDay(uid, kind, ds);
        } on NexonError catch (e) {
          if (d.isBefore(t)) errors.add('$kind $ds: $e'); // 오늘 데이터는 아직 없을 수 있음
        }
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    }
    // 스타포스 비용에 필요한 장비 레벨: 모르는 장비가 있으면 그 캐릭터 장비를 받아온다
    final tracked = {for (final c in chars.searchWithOcid(uid)) c['name'] as String: c['ocid'] as String};
    for (final name in repo.charsWithUnknownItems(uid)) {
      try {
        // 등록 안 한 같은 계정 캐릭터는 이름으로 ocid를 찾는다
        final ocid = tracked[name] ?? await cache.cached<String?>('ocid:$name', 86400 * 7, () => nexon.findOcid(name));
        if (ocid == null) throw NexonError('캐릭터를 찾지 못했어요');
        await equipment.equipmentFor(nexon, ocid, ttl: 0);
        await Future<void>.delayed(const Duration(milliseconds: 200));
      } on NexonError catch (e) {
        errors.add('$name 장비: $e');
      }
    }
    price(uid);
    settings.set(uid, 'last_enhance_sync', nowKstIso());
    return {'added': added, 'errors': errors.take(10).toList()};
  }
}
