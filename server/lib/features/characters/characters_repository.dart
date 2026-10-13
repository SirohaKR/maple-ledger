// 캐릭터·프리셋 DB 조회. 모든 조회는 "내 캐릭터"(user_id)만.
import 'package:shared/shared.dart';

import '../../core/db.dart';
import '../../core/http.dart';

class CharactersRepository {
  final Db db;
  CharactersRepository(this.db);

  List<Row> search(int uid) => db.rows('SELECT * FROM characters WHERE user_id = ? ORDER BY sort, id', [uid]);

  /// ocid가 있는 내 캐릭터 (넥슨 API로 부를 수 있는 것).
  List<Row> searchWithOcid(int uid) =>
      db.rows('SELECT * FROM characters WHERE ocid IS NOT NULL AND user_id = ? ORDER BY sort, id', [uid]);

  /// 내 캐릭터인지 확인 (아니면 null).
  Row? own(int uid, Object? cid) {
    final id = toIntOrNull(cid);
    if (id == null) return null;
    return db.one('SELECT * FROM characters WHERE id = ? AND user_id = ?', [id, uid]);
  }

  /// 모든 캐릭터의 ocid → 주인 (다른 사람이 이미 등록했는지 확인용).
  Map<String, int?> owners() => {
        for (final r in db.rows('SELECT ocid, user_id FROM characters WHERE ocid IS NOT NULL'))
          r['ocid'] as String: r['user_id'] as int?,
      };

  /// 이름 → id (강화 기록의 캐릭터 이름을 내 캐릭터로 연결).
  Map<String, int> idsByName(int uid) =>
      {for (final r in db.rows('SELECT id, name FROM characters WHERE user_id = ?', [uid])) r['name'] as String: r['id'] as int};

  /// 넥슨 정보로 추가하거나 갱신 (다른 사람이 등록한 캐릭터면 오류).
  void upsert(int uid, Map<String, Object?> info) {
    final owner = db.one('SELECT user_id FROM characters WHERE ocid = ?', [info['ocid']]);
    if (owner != null && owner['user_id'] != uid) throw ApiError('${info['name']}: 다른 사용자가 이미 등록한 캐릭터예요', 502);
    final sort = db.scalar('SELECT COALESCE(MAX(sort), 0) + 1 FROM characters WHERE user_id = ?', [uid]);
    db.exec('''
        INSERT INTO characters (user_id, ocid, name, world, job, level, image, sort, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT (ocid) DO UPDATE SET
          name = excluded.name, world = excluded.world, job = excluded.job,
          level = excluded.level, image = COALESCE(excluded.image, characters.image),
          updated_at = excluded.updated_at''',
        [uid, info['ocid'], info['name'], info['world'], info['job'], info['level'], info['image'], sort, nowKstIso()]);
  }

  void setSort(int uid, int cid, int sort) =>
      db.exec('UPDATE characters SET sort = ? WHERE id = ? AND user_id = ?', [sort, cid, uid]);

  void delete(int uid, int cid) => db.exec('DELETE FROM characters WHERE id = ? AND user_id = ?', [cid, uid]);

  // ── 보스 프리셋 ──
  /// 내 캐릭터들의 프리셋 {character_id: [..]}.
  Map<int, List<Row>> presets(int uid) {
    final out = <int, List<Row>>{};
    for (final p in db.rows(
        'SELECT p.* FROM char_bosses p JOIN characters c ON c.id = p.character_id WHERE c.user_id = ?', [uid])) {
      out.putIfAbsent(p['character_id'] as int, () => []).add(p);
    }
    return out;
  }

  /// (character_id, boss_id) → 파티 인원.
  Map<(int, int), int> presetParty(int uid) => {
        for (final list in presets(uid).values)
          for (final p in list) (p['character_id'] as int, p['boss_id'] as int): p['party_size'] as int,
      };

  void replacePreset(int cid, List<Map<String, Object?>> items) => db.tx(() {
        db.exec('DELETE FROM char_bosses WHERE character_id = ?', [cid]);
        for (final it in items) {
          final party = toInt(it['party_size'], 1);
          db.exec('INSERT INTO char_bosses (character_id, boss_id, party_size, daily_count) VALUES (?, ?, ?, ?)',
              [cid, toInt(it['boss_id']), party < 1 ? 1 : party, toInt(it['daily_count'], 7) == 0 ? 7 : toInt(it['daily_count'], 7)]);
        }
      });
}
