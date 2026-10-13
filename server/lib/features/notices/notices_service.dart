// 공지 감시 — 넥슨 공지(업데이트·일반·이벤트)를 받아 감시 단어가 들어간 것을 표시.
import '../../core/context.dart';
import '../../core/settings_store.dart';
import '../../nexon/nexon_client.dart';
import '../sync/sync_service.dart' show epochNow;
import 'notices_repository.dart';

String? _day(Object? v) {
  final s = '${v ?? ''}';
  final d = s.length >= 10 ? s.substring(0, 10) : s;
  return d.isEmpty ? null : d;
}

class NoticesService {
  final AppContext app;
  final NoticesRepository repo;
  final SettingsStore settings;

  NoticesService(this.app)
      : repo = NoticesRepository(app.db),
        settings = SettingsStore(app.db);

  /// 새 공지를 받아 저장 — 감시 단어가 들어간 새 공지 수.
  Future<int> check(int uid) async {
    final key = settings.apiKey(uid);
    if (key.isEmpty) return 0;
    final nexon = app.nexonFor(key);
    final kws = (settings.get(uid, 'notice_keywords') ?? '').split(',').map((w) => w.trim()).where((w) => w.isNotEmpty).toList();
    final firstRun = repo.isEmpty();
    var found = 0;
    for (final kind in ['notice-update', 'notice', 'notice-event']) {
      for (final n in (await nexon.notices(kind)).take(20)) {
        final nid = '$kind:${n['notice_id']}';
        if (repo.exists(nid)) continue;
        var text = '${n['title'] ?? ''}';
        if (kind == 'notice-update' && kws.isNotEmpty) {
          // 업데이트 공지는 본문까지 본다
          try {
            text += ' ${(await nexon.noticeDetail(kind, n['notice_id']))['contents'] ?? ''}';
            await Future<void>.delayed(const Duration(milliseconds: 200));
          } on NexonError {
            // 본문을 못 받으면 제목만
          }
        }
        final matched = kws.where(text.contains).toList();
        if (matched.isNotEmpty) found++;
        repo.insert({
          'id': nid,
          'kind': kind,
          'title': n['title'],
          'url': n['url'],
          'date': _day(n['date']) ?? '',
          'matched': matched.isEmpty ? null : matched.join(','),
          'seen': firstRun ? 1 : 0,
          'date_start': _day(n['date_event_start']),
          'date_end': _day(n['date_event_end']),
        });
      }
    }
    settings.set(null, 'last_notice_check', epochNow());
    return found;
  }

  /// 1시간마다 — API 키를 가진 아무 사용자(관리자 먼저)의 키로.
  Future<void> checkPeriodic() async {
    final last = double.tryParse(settings.global('last_notice_check') ?? '') ?? 0;
    if (DateTime.now().millisecondsSinceEpoch / 1000 - last < 3600) return;
    final uid = repo.keyOwner();
    if (uid == null) return;
    try {
      await check(uid);
    } on NexonError catch (e) {
      print('[notice] $e');
      settings.set(null, 'last_notice_check', epochNow());
    }
  }
}
