// 보스 자동 체크 — 넥슨 스케줄러에서 완료한 보스를 읽어 보스 기록에 넣는다.
import 'dart:convert';

import 'package:shared/shared.dart';

import '../../core/context.dart';
import '../../core/db.dart';
import '../../core/settings_store.dart';
import '../../nexon/nexon_client.dart';
import '../bosses/bosses_repository.dart';
import '../characters/characters_repository.dart';
import '../week/clears_repository.dart';
import 'sync_repository.dart';

const _diffAliases = {'노말': '노멀', 'normal': '노멀', 'easy': '이지', 'hard': '하드', 'chaos': '카오스', 'extreme': '익스트림'};

/// 공백 없애고 소문자로 (API 이름과 내 보스 이름 비교용).
String _norm(Object? s) => (s ?? '').toString().replaceAll(RegExp(r'\s+'), '').toLowerCase();

String _normDiff(Object? s) {
  final n = _norm(s);
  return _diffAliases[n] ?? n;
}

String _normCycle(Object? s) {
  final n = _norm(s);
  if (n.contains('일') || n.contains('day') || n.contains('daily')) return 'daily';
  if (n.contains('월') || n.contains('month')) return 'monthly';
  return 'weekly';
}

bool _flag(Object? v) => const {'true', 'y', '1', 'yes', '완료'}.contains('$v'.trim().toLowerCase());

/// 지금 시각 (초, 파이썬 time.time()과 같은 형식).
String epochNow() => (DateTime.now().millisecondsSinceEpoch / 1000).toString();

class SyncService {
  /// 지금 자동 체크 중인 사람 (한 사람이 두 번 동시에 돌지 않게).
  static final _running = <int>{};
  static bool isRunning(int uid) => _running.contains(uid);

  final AppContext app;
  final Db db;
  final SyncRepository repo;
  final ClearsRepository clears;
  final BossesRepository bosses;
  final CharactersRepository chars;
  final SettingsStore settings;

  SyncService(this.app)
      : db = app.db,
        repo = SyncRepository(app.db),
        clears = ClearsRepository(app.db),
        bosses = BossesRepository(app.db),
        chars = CharactersRepository(app.db),
        settings = SettingsStore(app.db);

  /// 이미 도는 중이면 null.
  Future<Map<String, Object?>?> syncOnce(int uid) async {
    if (!_running.add(uid)) return null;
    try {
      return await run(uid);
    } finally {
      _running.remove(uid);
    }
  }

  Future<Map<String, Object?>> run(int uid) async {
    final key = settings.apiKey(uid);
    final added = <String>[], errors = <String>[];
    final unmatched = <String>{};
    final result = <String, Object?>{'at': nowKstIso(), 'chars': 0, 'added': added, 'unmatched': <String>[], 'errors': errors};
    if (key.isEmpty) {
      errors.add('넥슨 API 키가 없어요');
      return result;
    }
    final nexon = app.nexonFor(key);

    // (이름, 난이도, 주기) → 보스 id. 별칭(api_name)으로도 찾는다.
    final bossRows = bosses.searchForMatching();
    final index = <(String, String, String), int>{};
    for (final b in bossRows) {
      for (final nm in [b['name'], b['api_name']]) {
        if (nm != null && nm != '') index[(_norm(nm), _normDiff(b['difficulty']), b['cycle'] as String)] = b['id'] as int;
      }
    }
    final names = {for (final b in bossRows) b['id'] as int: '${b['difficulty']} ${b['name']}'};
    final presets = chars.presetParty(uid);
    int party(int cid, int bid) => presets[(cid, bid)] ?? 1;

    final t = todayKst(), ws = weekStart(t);
    final week = isoDate(ws), month = monthOf(t);
    final charRows = chars.searchWithOcid(uid);
    final cname = {for (final c in charRows) c['id'] as int: c['name']};

    void handle(int cid, Map<String, Object?> data, DateTime day) {
      for (final item in (data['boss_contents'] as List? ?? [])) {
        if (item is! Map || !_flag(item['complete_flag'])) continue;
        final cyc = _normCycle(item['cycle']);
        final bid = index[(_norm(item['content_name']), _normDiff(item['difficulty']), cyc)];
        if (bid == null) {
          unmatched.add('${item['content_name']} / ${item['difficulty']} / ${item['cycle']}');
          continue;
        }
        if (cyc == 'daily') {
          clears.logDaily(cid, bid, isoDate(day));
        } else {
          final period = cyc == 'weekly' ? week : monthOf(day);
          if (cyc == 'monthly' && period != month) continue;
          if (clears.insertFromApi(cid, bid, period, party(cid, bid))) added.add('${cname[cid]}: ${names[bid]}');
        }
      }
    }

    for (final c in charRows) {
      final cid = c['id'] as int, ocid = c['ocid'] as String;
      try {
        final live = await nexon.schedulerState(ocid);
        repo.saveState(cid, live);
        handle(cid, live, t);
        // 이번 주 지난 날짜의 일간 보스는 한 번씩만 받아온다
        final done = repo.doneDays(cid);
        for (var d = ws; d.isBefore(t); d = d.add(const Duration(days: 1))) {
          if (!done.contains(isoDate(d)) && t.difference(d).inDays <= 14) {
            await Future<void>.delayed(const Duration(milliseconds: 300));
            handle(cid, await nexon.schedulerState(ocid, isoDate(d)), d);
            repo.markDay(cid, isoDate(d));
          }
        }
        // 일간 보스: 이번 주 완료한 날 수를 횟수로 (직접 넣은 횟수가 더 크면 그대로)
        for (final r in clears.dailyCounts(cid, week, isoDate(ws.add(const Duration(days: 7))))) {
          final bid = r['boss_id'] as int;
          clears.upsertDailyFromApi(cid, bid, week, r['n'] as int, party(cid, bid));
        }
        result['chars'] = (result['chars'] as int) + 1;
        await Future<void>.delayed(const Duration(milliseconds: 300));
      } on NexonError catch (e) {
        errors.add('${c['name']}: $e');
      }
    }
    result['unmatched'] = unmatched.toList()..sort();
    settings.set(uid, 'sync_result', jsonEncode(result));
    settings.set(uid, 'last_sync', epochNow());
    return result;
  }
}
