// 보스·결정석 가격 DB 조회.
import '../../core/db.dart';

class BossesRepository {
  final Db db;
  BossesRepository(this.db);

  /// 보스 목록 (정렬 순서대로).
  List<Row> search() => db.rows('SELECT * FROM bosses ORDER BY sort, id');

  /// 자동 체크 매칭용 (이름·난이도·주기·별칭만).
  List<Row> searchForMatching() => db.rows('SELECT id, name, difficulty, cycle, api_name FROM bosses');

  Row? find(int id) => db.one('SELECT * FROM bosses WHERE id = ?', [id]);

  /// day 시점에 적용되는 보스별 가격 {boss_id: price}.
  Map<int, int> pricesOn(String day) => {
        for (final r in db.rows('''
            SELECT p.boss_id, p.price FROM boss_prices p
            WHERE p.effective_from = (
              SELECT MAX(effective_from) FROM boss_prices
              WHERE boss_id = p.boss_id AND effective_from <= ?)''', [day]))
          r['boss_id'] as int: r['price'] as int,
      };

  /// 보스별 가격 이력 (최신순).
  Map<int, List<Row>> priceHistory() {
    final out = <int, List<Row>>{};
    for (final r in db.rows('SELECT * FROM boss_prices ORDER BY effective_from DESC')) {
      out.putIfAbsent(r['boss_id'] as int, () => []).add(r);
    }
    return out;
  }

  bool exists(String name, String difficulty, String cycle) =>
      db.one('SELECT 1 FROM bosses WHERE name = ? AND difficulty = ? AND cycle = ?', [name, difficulty, cycle]) != null;

  int insert(String name, String difficulty, String cycle, int maxParty) {
    final sort = db.scalar('SELECT COALESCE(MAX(sort), 0) + 1 FROM bosses');
    return db.insert('INSERT INTO bosses (name, difficulty, cycle, max_party, sort) VALUES (?, ?, ?, ?, ?)',
        [name, difficulty, cycle, maxParty, sort]);
  }

  /// 바꿀 칸만 (name, difficulty, cycle, max_party, hidden, sort, api_name, image_url).
  void update(int id, Map<String, Object?> fields) {
    if (fields.isEmpty) return;
    db.exec('UPDATE bosses SET ${fields.keys.map((k) => '$k = ?').join(', ')} WHERE id = ?', [...fields.values, id]);
  }

  int countClears(int bossId) => db.scalar('SELECT COUNT(*) FROM clears WHERE boss_id = ?', [bossId]) as int;

  void delete(int id) => db.exec('DELETE FROM bosses WHERE id = ?', [id]);

  // ── 가격 ──
  void upsertPrice(int bossId, int price, String effectiveFrom) => db.exec(
      'INSERT OR REPLACE INTO boss_prices (boss_id, price, effective_from) VALUES (?, ?, ?)', [bossId, price, effectiveFrom]);

  Row? findPrice(int priceId) => db.one('SELECT * FROM boss_prices WHERE id = ?', [priceId]);

  int countPrices(int bossId) => db.scalar('SELECT COUNT(*) FROM boss_prices WHERE boss_id = ?', [bossId]) as int;

  void deletePrice(int priceId) => db.exec('DELETE FROM boss_prices WHERE id = ?', [priceId]);
}
