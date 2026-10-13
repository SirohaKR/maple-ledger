// 강화·성장 비용표와 계산식 — 커뮤니티 정리(나무위키) 기준, 2026-10 확인.
// 패치로 바뀌면 이 파일의 숫자만 고치면 된다. 웹에서 개별 기록의 비용은 직접 덮어쓸 수 있다.
import 'dart:math' as math;

// ───────── 스타포스 ─────────
// 1회 비용 = 1000 + L^3 × (S+1) / 36                (0~9성)
//          = 1000 + L^3 × (S+1)^2.7 / 나누는 값      (10성~)
// L = 장비 착용 레벨, S = 현재 성. 100의 자리로 반올림.
// 23성 이상은 공식을 확인하지 못해서 비워 뒀다(null = 비용 계산 안 함).
const Map<int, int?> starforceDivisors = {
  10: 571, 11: 314, 12: 214, 13: 157, 14: 107,
  15: 200, 16: 200, 17: 150, 18: 70, 19: 45,
  20: 200, 21: 125, 22: 200,
  23: null, 24: null, 25: null, 26: null, 27: null, 28: null, 29: null,
};
const int starforceMvpMaxStar = 17; // MVP·PC방 할인은 17성 미만에만 적용
const double destroyDefenceRate = 2.0; // 파괴 방지: 기본 비용의 200% 추가 (할인 없음)

/// 파이썬 round()와 같은 반올림 (정확히 .5면 짝수 쪽으로).
int roundHalfEven(double x) {
  final f = x.floorToDouble();
  final diff = x - f;
  if (diff > 0.5) return f.toInt() + 1;
  if (diff < 0.5) return f.toInt();
  return f.toInt().isEven ? f.toInt() : f.toInt() + 1;
}

/// 할인 전 1회 비용. 공식을 모르는 구간이면 null.
int? starforceBase(int? level, int? star) {
  if (level == null || level == 0 || star == null || star < 0) return null;
  double cost;
  if (star <= 9) {
    cost = 1000 + math.pow(level, 3) * (star + 1) / 36;
  } else {
    final d = starforceDivisors[star];
    if (d == null || d == 0) return null;
    cost = 1000 + math.pow(level, 3) * math.pow(star + 1, 2.7) / d;
  }
  return roundHalfEven(cost / 100.0) * 100;
}

/// starforce_event_list 중 이 성에 해당하는 비용 할인율(%).
double _eventDiscount(List<dynamic>? events, int star) {
  var best = 0.0;
  for (final ev in events ?? const []) {
    if (ev is! Map) continue;
    final rate = ev['cost_discount_rate'];
    if (rate == null || rate == '' || rate == 0) continue;
    final rng = (ev['starforce_event_range'] ?? '').toString();
    final nums = rng
        .replaceAll('성', '')
        .replaceAll('~', ' ')
        .replaceAll('-', ' ')
        .split(RegExp(r'\s+'))
        .where((x) => RegExp(r'^\d+$').hasMatch(x))
        .map(int.parse)
        .toList();
    if (nums.length >= 2 && !(nums[0] <= star && star <= nums[1])) continue;
    final r = double.tryParse(rate.toString());
    if (r != null && r > best) best = r;
  }
  return best;
}

int? starforceCost(int? level, int? star,
    {bool destroyDefence = false, double mvpDiscount = 0, List<dynamic>? events}) {
  final base = starforceBase(level, star);
  if (base == null || star == null) return null;
  var rate = 1.0;
  if (star < starforceMvpMaxStar) rate *= 1 - mvpDiscount / 100;
  final ev = _eventDiscount(events, star);
  if (ev != 0) rate *= 1 - ev / 100;
  var cost = base * rate;
  if (destroyDefence) cost += base * destroyDefenceRate;
  return cost.truncate();
}

// ───────── 장비 레벨 추측 ─────────
// 넥슨 API는 지금 끼고 있는 장비만 알려 줘서, 벗어 둔 장비는 레벨을 모른다. 그럴 때 이름으로 추측한다.
const Map<String, int> setLevels = {
  '에테르넬': 250,
  '제네시스': 200,
  '아케인셰이드': 200,
  '앱솔랩스': 160,
  '하이네스': 150, '이글아이': 150, '트릭스터': 150, '파프니르': 150, // 루타비스
};

/// 이름 앞부분(세트 이름)으로 레벨 추측. 알려진 세트가 아니면 [known]에서 같은 세트 장비의 레벨을 빌려 온다
/// (같은 세트 장비 레벨이 서로 다르면 모른다고 둔다).
int? guessItemLevel(String? name, Map<String, int?> known) {
  if (name == null || name.isEmpty) return null;
  for (final e in setLevels.entries) {
    if (name.startsWith(e.key)) return e.value;
  }
  final space = name.indexOf(' ');
  if (space <= 0) return null;
  final prefix = name.substring(0, space + 1);
  final levels = {
    for (final e in known.entries)
      if (e.value != null && e.key != name && e.key.startsWith(prefix)) e.value!,
  };
  return levels.length == 1 ? levels.first : null;
}

// ───────── 잠재능력 재설정 (메소) ─────────
// (레벨 하한, {등급: 1회 비용}) — 현재(사용 전) 등급 기준
const List<(int, Map<String, int>)> potentialCosts = [
  (250, {'레어': 5000000, '에픽': 20000000, '유니크': 42500000, '레전드리': 50000000}),
  (200, {'레어': 4500000, '에픽': 18000000, '유니크': 38250000, '레전드리': 45000000}),
  (160, {'레어': 4250000, '에픽': 17000000, '유니크': 36125000, '레전드리': 42500000}),
  (0, {'레어': 4000000, '에픽': 16000000, '유니크': 34000000, '레전드리': 40000000}),
];
const List<(int, Map<String, int>)> additionalCosts = [
  (250, {'레어': 12250000, '에픽': 34300000, '유니크': 83300000, '레전드리': 98000000}),
  (200, {'레어': 11000000, '에픽': 30800000, '유니크': 74800000, '레전드리': 88000000}),
  (160, {'레어': 10375000, '에픽': 29050000, '유니크': 70550000, '레전드리': 83000000}),
  (0, {'레어': 9750000, '에픽': 27300000, '유니크': 66300000, '레전드리': 78000000}),
];
const List<String> grades = ['레어', '에픽', '유니크', '레전드리'];

int? potentialCost(int? level, String? grade, {bool additional = false}) {
  if (level == null || level == 0 || grade == null || !grades.contains(grade)) return null;
  for (final (lo, table) in additional ? additionalCosts : potentialCosts) {
    if (level >= lo) return table[grade];
  }
  return null;
}

/// 등급이 올랐으면 사용 전 등급은 한 단계 아래.
String? gradeBefore(String? afterGrade, bool upgraded) {
  if (afterGrade == null || !grades.contains(afterGrade)) return afterGrade;
  final i = grades.indexOf(afterGrade);
  return upgraded ? grades[math.max(0, i - 1)] : afterGrade;
}

// ───────── HEXA 코어 ─────────
// 레벨 n 행 = (n-1 → n) 강화 재료 (솔 에르다, 솔 에르다 조각). 1행 = 활성화.
const Map<String, List<(int, int)>> hexaCosts = {
  '스킬': [(5, 100), (1, 30), (1, 35), (1, 40), (2, 45), (2, 50), (2, 55), (3, 60), (3, 65), (10, 200),
    (3, 80), (3, 90), (4, 100), (4, 110), (4, 120), (4, 130), (4, 140), (4, 150), (5, 160), (15, 350),
    (5, 170), (5, 180), (5, 190), (5, 200), (5, 210), (6, 220), (6, 230), (6, 240), (7, 250), (20, 500)],
  '마스터리': [(3, 50), (1, 15), (1, 18), (1, 20), (1, 23), (1, 25), (1, 28), (2, 30), (2, 33), (5, 100),
    (2, 40), (2, 45), (2, 50), (2, 55), (2, 60), (2, 65), (2, 70), (2, 75), (3, 80), (8, 175),
    (3, 85), (3, 90), (3, 95), (3, 100), (3, 105), (3, 110), (3, 115), (3, 120), (4, 125), (10, 250)],
  '강화': [(4, 75), (1, 23), (1, 27), (1, 30), (2, 34), (2, 38), (2, 42), (3, 45), (3, 49), (8, 150),
    (3, 60), (3, 68), (3, 75), (3, 83), (3, 90), (3, 98), (3, 105), (3, 113), (4, 120), (12, 263),
    (4, 128), (4, 135), (4, 143), (4, 150), (4, 158), (5, 165), (5, 173), (5, 180), (6, 188), (15, 375)],
  '공용': [(7, 125), (2, 38), (2, 44), (2, 50), (3, 57), (3, 63), (3, 69), (5, 75), (5, 82), (14, 300),
    (5, 110), (5, 124), (6, 138), (6, 152), (6, 165), (6, 179), (6, 193), (6, 207), (7, 220), (17, 525),
    (7, 234), (7, 248), (7, 262), (7, 275), (7, 289), (9, 303), (9, 317), (9, 330), (10, 344), (20, 750)],
};
const int hexaMax = 30;

String? hexaKind(String? coreType) {
  final t = coreType ?? '';
  for (final k in ['마스터리', '강화', '공용', '스킬']) {
    if (t.contains(k)) return k;
  }
  return null;
}

/// 현재 레벨에서 30레벨까지 남은 (솔 에르다, 조각)과 다음 레벨 비용.
Map<String, Object?>? hexaRemaining(String? coreType, Object? level) {
  final table = hexaCosts[hexaKind(coreType)];
  if (table == null) return null;
  final lv = (int.tryParse('${level ?? 0}') ?? 0).clamp(0, hexaMax);
  final rest = table.sublist(lv);
  return {
    'erda': rest.fold<int>(0, (a, e) => a + e.$1),
    'fragments': rest.fold<int>(0, (a, e) => a + e.$2),
    'next': lv < hexaMax ? [table[lv].$1, table[lv].$2] : null,
    'total_fragments': table.fold<int>(0, (a, e) => a + e.$2),
  };
}
