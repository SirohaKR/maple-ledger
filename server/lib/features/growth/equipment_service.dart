// 장착 장비 받아오기 — 받으면서 장비 이름 → 착용 레벨·아이콘·툴팁을 item_info에 기억해 둔다.
// 성장 화면(장비 목록)과 지출 화면(스타포스 비용 계산)이 같이 쓴다.
import 'package:shared/shared.dart';

import '../../core/db.dart';
import '../../nexon/api_cache.dart';
import '../../nexon/nexon_client.dart';
import 'growth_repository.dart';

const itemDetailKeys = [
  'item_equipment_slot', 'item_equipment_part', 'item_name', 'item_icon', 'starforce', 'starforce_scroll_flag',
  'scroll_upgrade', 'scroll_upgradable_count', 'scroll_resilience_count', 'cuttable_count', 'golden_hammer_flag',
  'item_total_option', 'item_base_option', 'item_add_option', 'item_etc_option', 'item_starforce_option',
  'item_exceptional_option', 'potential_option_grade', 'additional_potential_option_grade',
  'potential_option_1', 'potential_option_2', 'potential_option_3',
  'additional_potential_option_1', 'additional_potential_option_2', 'additional_potential_option_3',
  'soul_name', 'soul_option', 'special_ring_level',
];

/// 장비 응답에서 툴팁에 필요한 것만.
Map<String, Object?> itemDetail(Map it) => {
      for (final k in itemDetailKeys)
        if (it[k] != null && it[k] != '' && !(it[k] is Map && (it[k] as Map).isEmpty)) k: it[k],
    };

const _equipLists = ['item_equipment', 'item_equipment_preset_1', 'item_equipment_preset_2', 'item_equipment_preset_3',
    'dragon_equipment', 'mechanic_equipment'];

class EquipmentService {
  final ApiCache cache;
  final GrowthRepository repo;

  EquipmentService(Db db)
      : cache = ApiCache(db),
        repo = GrowthRepository(db);

  Future<Map<String, dynamic>> equipmentFor(NexonClient nexon, String ocid, {int ttl = 1800}) async {
    final data = Map<String, dynamic>.from(await cache.cached('equip:$ocid', ttl, () => nexon.itemEquipment(ocid)) as Map);
    final now = nowKstIso();
    for (final k in _equipLists) {
      for (final it in (data[k] as List? ?? [])) {
        if (it is! Map || it['item_name'] == null || it['item_name'] == '') continue;
        final base = it['item_base_option'];
        final lv = int.tryParse('${base is Map ? base['base_equipment_level'] ?? 0 : 0}') ?? 0;
        repo.upsertItem(it['item_name'] as String, lv == 0 ? null : lv, it['item_icon'], now, itemDetail(it));
      }
    }
    return data;
  }
}
