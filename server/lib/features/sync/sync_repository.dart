// 자동 체크 DB 조회 — 받아온 날짜, 마지막 스케줄러 응답.
import 'dart:convert';

import 'package:shared/shared.dart';

import '../../core/db.dart';

class SyncRepository {
  final Db db;
  SyncRepository(this.db);

  Set<String> doneDays(int cid) =>
      {for (final r in db.rows('SELECT date FROM sync_days WHERE character_id = ?', [cid])) r['date'] as String};

  void markDay(int cid, String date) => db.exec('INSERT OR IGNORE INTO sync_days VALUES (?, ?)', [cid, date]);

  void saveState(int cid, Map<String, Object?> data) =>
      db.exec('INSERT OR REPLACE INTO sched_state VALUES (?, ?, ?)', [cid, nowKstIso(), jsonEncode(data)]);

  /// 내 캐릭터들의 마지막 스케줄러 응답 (숙제 화면).
  List<Row> searchStates(int uid) => db.rows('''
      SELECT c.id, c.name, c.world, c.job, c.level, c.image, s.fetched_at, s.data
      FROM characters c LEFT JOIN sched_state s ON s.character_id = c.id
      WHERE c.user_id = ? ORDER BY c.sort, c.id''', [uid]);
}
