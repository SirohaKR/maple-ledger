// 수익 계산식 — 서버가 저장·통계에 쓰고, 앱도 입력 중 미리보기에 같은 식을 쓴다.

int _i(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
double _d(Object? v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;
bool _truthy(Object? v) => v == true || (v is num && v != 0) || v == '1' || v == 'true';

/// 기타 수익의 내 실수령액 = 판매 총액 × (1 - 수수료)을 파티 분배.
/// 비율 분배는 파티장 1명 : 파티원 (인원-1)명. 예) 7:3 2인 → 파티장 70%, 파티원 30%.
int incomeAmount(Map<String, Object?> r) {
  final net = _i(r['gross']) * (1 - _d(r['fee_rate']) / 100);
  final n = _i(r['party_size']) < 1 ? 1 : _i(r['party_size']);
  if (n == 1) return net.truncate();
  if (r['split'] == 'ratio') {
    final lw = _i(r['leader_ratio']) < 0 ? 0 : _i(r['leader_ratio']);
    final mw = _i(r['member_ratio']) < 0 ? 0 : _i(r['member_ratio']);
    final total = lw + mw * (n - 1);
    if (total <= 0) return 0;
    return (net * (r['role'] == 'leader' ? lw : mw) / total).truncate();
  }
  return (net / n).truncate();
}

/// 사냥 1회 수익 = 메소 + 부수입 + (판매 체크 시) 조각 × 시세 × (1 - 수수료).
({int fragmentIncome, int total}) huntParts(Map<String, Object?> h) {
  var frag = 0;
  if (_truthy(h['fragments_sold']) && _i(h['fragments']) != 0) {
    frag = (_i(h['fragments']) * _i(h['fragment_price']) * (1 - _d(h['fragment_fee']) / 100)).truncate();
  }
  return (fragmentIncome: frag, total: _i(h['meso']) + _i(h['extra']) + frag);
}

/// 결정석 판매 한도 적용.
/// clears: 그 주의 클리어 기록 (id, character_id, cycle, count, share, world 필요).
/// 캐릭터마다 결정석을 1개 단위로 펼쳐 비싼 순으로 캐릭터 한도까지 → 같은 월드끼리 모아 월드 한도까지.
/// 결과: 각 clear에 sold(팔린 개수), income(수익)을 채우고, 월드별 팔린 개수를 돌려준다.
Map<String, int> applyCrystalLimits(List<Map<String, Object?>> clears,
    {required int charLimit, required int worldLimit, required bool dailyInLimit}) {
  final byId = {for (final c in clears) c['id']: c};
  final byChar = <Object?, List<Map<String, Object?>>>{};
  for (final c in clears) {
    c['sold'] = 0;
    c['income'] = 0;
    byChar.putIfAbsent(c['character_id'], () => []).add(c);
  }
  final limitedUnits = <(int, Object?, Object?)>[]; // (1개 몫, clear id, 월드)
  final freeUnits = <(int, Object?, Object?)>[];
  for (final items in byChar.values) {
    final limited = <(int, Object?, Object?)>[];
    for (final it in items) {
      final unit = (_i(it['share']), it['id'], it['world']);
      final count = _i(it['count']) < 0 ? 0 : _i(it['count']);
      final target = (it['cycle'] == 'weekly' || dailyInLimit) ? limited : freeUnits;
      for (var k = 0; k < count; k++) {
        target.add(unit);
      }
    }
    limited.sort((a, b) => b.$1.compareTo(a.$1));
    limitedUnits.addAll(charLimit > 0 && limited.length > charLimit ? limited.sublist(0, charLimit) : limited);
  }
  final perWorld = <Object?, List<(int, Object?, Object?)>>{};
  for (final u in limitedUnits) {
    perWorld.putIfAbsent(u.$3, () => []).add(u);
  }
  final sold = <(int, Object?, Object?)>[];
  for (final units in perWorld.values) {
    units.sort((a, b) => b.$1.compareTo(a.$1));
    sold.addAll(worldLimit > 0 && units.length > worldLimit ? units.sublist(0, worldLimit) : units);
  }
  final worlds = <String, int>{};
  for (final u in sold) {
    worlds['${u.$3}'] = (worlds['${u.$3}'] ?? 0) + 1;
  }
  for (final u in [...sold, ...freeUnits]) {
    final c = byId[u.$2]!;
    c['sold'] = _i(c['sold']) + 1;
    c['income'] = _i(c['income']) + u.$1;
  }
  return worlds;
}
