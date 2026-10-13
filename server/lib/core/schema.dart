// DB 테이블 정의 방식 — 각 기능 폴더(features/*/..._schema.dart)가 자기 테이블을 이 모양으로 알려 주고,
// 서버가 켜질 때 전부 모아서 만든다 (이미 있으면 건너뜀, 예전 DB에 없는 칸은 추가).
import 'db.dart';

class Schema {
  /// 이 기능이 쓰는 테이블 (CREATE TABLE IF NOT EXISTS …).
  final List<String> tables;

  /// 예전 DB에 나중에 생긴 칸: {테이블: {칸: 정의}}.
  final Map<String, Map<String, String>> columns;

  /// 인덱스 등 칸 추가 후에 실행할 문장.
  final List<String> after;

  /// 기본 데이터 넣기 (비어 있을 때만 넣도록 각자 확인).
  final void Function(Db db)? seed;

  const Schema({this.tables = const [], this.columns = const {}, this.after = const [], this.seed});
}

void applySchemas(Db db, List<Schema> schemas) {
  // 1인용 시절 history_days(kind, date)는 사람별로 바뀌어서 지우고 다시 만든다 (다시 불러오면 채워짐)
  final old = db.rows('PRAGMA table_info(history_days)').map((r) => r['name']).toList();
  if (old.isNotEmpty && !old.contains('user_id')) db.exec('DROP TABLE history_days');

  for (final s in schemas) {
    for (final sql in s.tables) {
      db.raw.execute(sql);
    }
  }
  for (final s in schemas) {
    s.columns.forEach(db.addColumns);
  }
  for (final s in schemas) {
    for (final sql in s.after) {
      db.raw.execute(sql);
    }
  }
  for (final s in schemas) {
    s.seed?.call(db);
  }
}
