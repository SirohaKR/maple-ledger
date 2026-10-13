// 날짜 도구 — 메이플은 한국 시간(KST, UTC+9, 서머타임 없음) 기준.

/// 지금 한국 시간 (DateTime 값은 UTC로 들고 있지만 시·분 숫자는 한국 시간).
DateTime nowKst() => DateTime.now().toUtc().add(const Duration(hours: 9));

/// 오늘 날짜 (한국 시간, 시·분 없음).
DateTime todayKst() {
  final n = nowKst();
  return DateTime.utc(n.year, n.month, n.day);
}

/// 2026-10-13 형식.
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// 2026-10-13T09:30:00+09:00 형식 (파이썬 isoformat(timespec="seconds")과 같은 모양).
String isoKst(DateTime kst) =>
    '${isoDate(kst)}T${kst.hour.toString().padLeft(2, '0')}:${kst.minute.toString().padLeft(2, '0')}:${kst.second.toString().padLeft(2, '0')}+09:00';

String nowKstIso() => isoKst(nowKst());

/// '2026-10-13' → 날짜 (틀리면 null).
DateTime? parseDate(Object? s) {
  if (s == null) return null;
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(s.toString().trim());
  if (m == null) return null;
  final d = DateTime.utc(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  return isoDate(d) == s.toString().trim() ? d : null; // 2월 30일 같은 날짜 거르기
}

/// '2026-10-13T09:30:00+09:00' 같은 일시 → 한국 시간 DateTime (UTC 값에 시·분 숫자만 KST).
DateTime? parseKst(Object? s) {
  if (s == null) return null;
  final d = DateTime.tryParse(s.toString());
  if (d == null) return null;
  return d.toUtc().add(const Duration(hours: 9));
}

/// 메이플 주간 초기화는 목요일 00시(KST).
DateTime weekStart(DateTime d) => d.subtract(Duration(days: (d.weekday - DateTime.thursday) % 7));

/// 2026-10 형식.
String monthOf(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';
