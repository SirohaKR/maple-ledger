// 백그라운드 작업 — 1분마다 돌면서
//   · 사람마다 자동 체크 주기가 됐으면 보스 자동 체크
//   · 새벽 3시 이후 하루 한 번: 전날 스냅샷(경험치·전투력) + 최근 3일 강화 기록
//   · 1시간마다 공지 확인
import 'dart:async';

import 'package:shared/shared.dart';

import '../core/context.dart';
import '../core/http.dart';
import '../core/settings_store.dart';
import '../nexon/nexon_client.dart';
import '../features/characters/characters_repository.dart';
import '../features/growth/growth_service.dart';
import '../features/notices/notices_service.dart';
import '../features/spend/enhance_service.dart';
import '../features/sync/sync_service.dart';

class Jobs {
  final AppContext app;
  final SettingsStore settings;
  final SyncService sync;
  final EnhanceService enhance;
  final GrowthService growth;
  final NoticesService notices;
  final CharactersRepository chars;
  final _dailyRunning = <int>{};
  Timer? _timer;
  bool _busy = false;

  Jobs(this.app)
      : settings = SettingsStore(app.db),
        sync = SyncService(app),
        enhance = EnhanceService(app),
        growth = GrowthService(app.db),
        notices = NoticesService(app),
        chars = CharactersRepository(app.db);

  void start() => _timer = Timer.periodic(const Duration(seconds: 60), (_) => tick());

  void stop() => _timer?.cancel();

  List<int> _usersWithKey() => [
        for (final r in app.db.rows("SELECT user_id FROM user_settings WHERE key = 'nexon_api_key' AND value <> ''"))
          r['user_id'] as int,
      ];

  Future<void> tick() async {
    if (_busy) return; // 앞의 작업이 아직 안 끝났으면 건너뜀
    _busy = true;
    try {
      for (final uid in _usersWithKey()) {
        try {
          final s = settings.all(uid);
          final interval = toInt(s['sync_interval']);
          final last = double.tryParse(s['last_sync'] ?? '') ?? 0;
          if (interval > 0 && DateTime.now().millisecondsSinceEpoch / 1000 - last >= interval * 60) {
            await sync.syncOnce(uid);
          }
          await daily(uid);
        } catch (e) {
          print('[sync] 사용자 $uid 오류: $e'); // 백그라운드 작업은 죽으면 안 됨
        }
      }
      try {
        await notices.checkPeriodic();
      } catch (e) {
        print('[notice] 오류: $e');
      }
    } finally {
      _busy = false;
    }
  }

  /// 하루 한 번: 이 사람 캐릭터들의 전날 스냅샷 + 강화 기록.
  Future<void> daily(int uid) async {
    if (!_dailyRunning.add(uid)) return;
    try {
      final key = settings.apiKey(uid);
      if (key.isEmpty) return;
      final now = nowKst(), today = isoDate(now);
      // 전날 데이터는 새벽 2시 이후에 나오니 3시 이후 하루 한 번
      if (now.hour < 3 || settings.get(uid, 'last_daily') == today) return;
      final y = isoDate(todayKst().subtract(const Duration(days: 1)));
      final nexon = app.nexonFor(key);
      for (final c in chars.searchWithOcid(uid)) {
        try {
          if (!growth.repo.hasDaily(c['id'] as int, y)) await growth.snapshot(nexon, c['id'] as int, c['ocid'] as String, y);
        } on NexonError catch (e) {
          print('[daily] ${c['name']}: $e');
        }
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
      try {
        await enhance.syncOnce(uid, days: 3);
      } on NexonError catch (e) {
        print('[daily] 강화 기록: $e');
      }
      settings.set(uid, 'last_daily', today);
    } finally {
      _dailyRunning.remove(uid);
    }
  }
}
