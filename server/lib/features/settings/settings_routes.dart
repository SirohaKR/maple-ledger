// 설정 화면 API — 내 설정, 결정석 판매 규칙(관리자).
import 'dart:convert';

import 'package:shared/shared.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../core/context.dart';
import '../../core/http.dart';
import '../../core/settings_store.dart';
import '../sync/sync_service.dart';
import 'rules_repository.dart';

class SettingsRoutes {
  final AppContext app;
  final SettingsStore settings;
  final RulesRepository rules;

  SettingsRoutes(this.app)
      : settings = SettingsStore(app.db),
        rules = RulesRepository(app.db);

  void register(Router r) {
    r.get('/api/settings', (Request req) => json(view(req.ctx)));
    r.put('/api/settings', _save);
    r.post('/api/rules', _addRule);
    r.delete('/api/rules/<id>', _deleteRule);
  }

  /// 화면에 보낼 설정 (API 키는 끝 4자리만).
  Map<String, Object?> view(Ctx ctx) {
    final uid = ctx.user;
    final s = <String, Object?>{...settings.all(uid)};
    final key = (s.remove('nexon_api_key') as String?) ?? '';
    s['nexon_key_set'] = key.isNotEmpty;
    s['nexon_key_hint'] = key.isNotEmpty ? '…${key.substring(key.length < 4 ? 0 : key.length - 4)}' : '';
    s['rules'] = rules.search();
    final sr = s['sync_result'] as String?;
    s['sync_result'] = sr == null || sr.isEmpty ? null : jsonDecode(sr);
    s['sync_running'] = SyncService.isRunning(uid);
    s['ledger_start'] = settings.ledgerStart(uid);
    s['spend_count_from'] = spendCountFrom; // 장부 시작일은 이 날보다 앞으로 못 정함
    s.remove('invite_code');
    s.remove('changelog_reset_v1');
    s['is_admin'] = ctx.isAdmin;
    return s;
  }

  Future<Response> _save(Request req) async {
    final ctx = req.ctx, uid = ctx.user, b = await body(req);
    if (truthy(b['nexon_api_key'])) settings.set(uid, 'nexon_api_key', b['nexon_api_key'].toString().trim());
    if (truthy(b['clear_nexon_api_key'])) {
      app.db.exec("DELETE FROM user_settings WHERE user_id = ? AND key = 'nexon_api_key'", [uid]);
    }
    for (final k in ['sync_interval', 'fragment_price', 'fragment_fee', 'starforce_discount', 'enhance_backfill_days']) {
      if (b.containsKey(k) && b[k] != null && b[k] != '') {
        final isFloat = k == 'fragment_fee' || k == 'starforce_discount';
        final v = isFloat ? toDoubleOrNull(b[k]) : toIntOrNull(b[k]);
        if (v == null) throw ApiError('$k 값이 숫자가 아니에요');
        settings.set(uid, k, isFloat ? v.toDouble().toString() : v.toString());
      }
    }
    final ls = parseDate(b['ledger_start']);
    if (ls != null) settings.set(uid, 'ledger_start', isoDate(ls));
    if (b.containsKey('notice_keywords') && ctx.isAdmin) {
      settings.set(uid, 'notice_keywords',
          b['notice_keywords'].toString().split(',').map((w) => w.trim()).where((w) => w.isNotEmpty).join(','));
    }
    return json(view(ctx));
  }

  Future<Response> _addRule(Request req) async {
    req.ctx.requireAdmin();
    final b = await body(req);
    final eff = parseDate(b['effective_from']) ?? (throw ApiError('적용일을 넣어 주세요'));
    rules.upsert(isoDate(eff), toInt(b['char_limit']), toInt(b['world_limit']), truthy(b['daily_in_limit']));
    return json(view(req.ctx));
  }

  Response _deleteRule(Request req, String id) {
    req.ctx.requireAdmin();
    if (rules.count() <= 1) throw ApiError('규칙이 하나뿐이라 지울 수 없어요');
    rules.delete(pathInt(id));
    return json(view(req.ctx));
  }
}
