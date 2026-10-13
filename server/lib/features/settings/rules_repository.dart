// 결정석 판매 규칙 DB 조회 (적용일별).
import '../../core/db.dart';

class RulesRepository {
  final Db db;
  RulesRepository(this.db);

  List<Row> search() => db.rows('SELECT * FROM crystal_rules ORDER BY effective_from DESC');

  /// day 시점에 적용되는 규칙.
  Row ruleOn(String day) =>
      db.one('SELECT * FROM crystal_rules WHERE effective_from <= ? ORDER BY effective_from DESC LIMIT 1', [day]) ??
      {'char_limit': 0, 'world_limit': 0, 'daily_in_limit': 1};

  int count() => db.scalar('SELECT COUNT(*) FROM crystal_rules') as int;

  void upsert(String effectiveFrom, int charLimit, int worldLimit, bool dailyInLimit) => db.exec(
      'INSERT OR REPLACE INTO crystal_rules (effective_from, char_limit, world_limit, daily_in_limit) VALUES (?, ?, ?, ?)',
      [effectiveFrom, charLimit, worldLimit, dailyInLimit ? 1 : 0]);

  void delete(int id) => db.exec('DELETE FROM crystal_rules WHERE id = ?', [id]);
}
