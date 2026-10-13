// 메소 표시·입력 — 화면(앱)에서 주로 쓰지만 서버 메시지에도 쓸 수 있게 공용으로.

/// 1560000000 → "15억 6,000만"
String fmtMeso(num? n) {
  if (n == null) return '-';
  final neg = n < 0;
  final v = n.abs().toInt();
  final eok = v ~/ 100000000, man = (v % 100000000) ~/ 10000, rest = v % 10000;
  final parts = <String>[];
  if (eok > 0) parts.add('${_comma(eok)}억');
  if (man > 0) parts.add('${_comma(man)}만');
  if (eok == 0 && man == 0) parts.add(_comma(rest));
  return (neg ? '-' : '') + parts.join(' ');
}

String _comma(int v) => v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

/// "15억 6000만", "1,560,000,000", "3.5억" 모두 허용. 못 읽으면 null.
int? parseMeso(Object? input) {
  if (input == null) return null;
  final s = input.toString().replaceAll(RegExp(r'[,\s]'), '');
  if (s.isEmpty) return null;
  if (RegExp('[억만]').hasMatch(s)) {
    var total = 0.0;
    final eok = RegExp(r'([\d.]+)억').firstMatch(s);
    final man = RegExp(r'([\d.]+)만').firstMatch(s);
    if (eok != null) total += (double.tryParse(eok[1]!) ?? 0) * 1e8;
    if (man != null) total += (double.tryParse(man[1]!) ?? 0) * 1e4;
    final tail = s.replaceFirst(RegExp(r'[\d.]+억'), '').replaceFirst(RegExp(r'[\d.]+만'), '');
    if (RegExp(r'^\d+$').hasMatch(tail)) total += int.parse(tail);
    return total.round();
  }
  return int.tryParse(RegExp(r'^-?\d+').stringMatch(s) ?? '');
}
