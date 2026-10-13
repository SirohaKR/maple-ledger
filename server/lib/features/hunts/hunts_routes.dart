// 사냥 API — 목록, 직접 입력, 타이머(시작 → 종료 → 기록 저장), 수정, 삭제.
import 'package:shared/shared.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../core/context.dart';
import '../../core/http.dart';
import '../../core/settings_store.dart';
import '../characters/characters_repository.dart';
import 'hunts_repository.dart';

const _fields = ['character_id', 'date', 'place', 'minutes', 'meso', 'meso_start', 'meso_end',
    'fragments', 'extra', 'fragments_sold', 'fragment_price', 'fragment_fee', 'note'];

class HuntsRoutes {
  final HuntsRepository hunts;
  final CharactersRepository chars;
  final SettingsStore settings;

  HuntsRoutes(AppContext app)
      : hunts = HuntsRepository(app.db),
        chars = CharactersRepository(app.db),
        settings = SettingsStore(app.db);

  void register(Router r) {
    r.get('/api/hunts', _list);
    r.post('/api/hunts', _add);
    r.post('/api/hunts/start', _start);
    r.post('/api/hunts/<id>/end', _end);
    r.post('/api/hunts/<id>/resume', _resume);
    r.post('/api/hunts/<id>/stop', _stop);
    r.put('/api/hunts/<id>', _edit);
    r.delete('/api/hunts/<id>', _delete);
  }

  /// 화면에서 온 값 정리 (보낸 칸만).
  Map<String, Object?> _clean(int uid, Map<String, Object?> b) {
    final out = <String, Object?>{};
    for (final k in _fields) {
      if (!b.containsKey(k)) continue;
      final v = b[k];
      out[k] = switch (k) {
        'place' || 'note' || 'date' => strOrNull(v),
        'fragments_sold' => truthy(v) ? 1 : 0,
        'fragment_fee' => toDoubleOrNull(v),
        _ => toIntOrNull(v),
      };
    }
    if (out['meso'] == null && out['meso_start'] != null && out['meso_end'] != null) {
      out['meso'] = (out['meso_end'] as int) - (out['meso_start'] as int);
    }
    if (truthy(out['character_id']) && chars.own(uid, out['character_id']) == null) out['character_id'] = null;
    return out;
  }

  /// 조각 시세·수수료를 저장 시점 값으로 고정 (안 넣었으면 설정값).
  Map<String, Object?> _snapshot(int uid, Map<String, Object?> h) {
    final s = settings.all(uid);
    h['fragment_price'] ??= toInt(s['fragment_price']);
    h['fragment_fee'] ??= toDoubleOrNull(s['fragment_fee']) ?? 0.0;
    return h;
  }

  Response _list(Request req) {
    final q = req.url.queryParameters;
    final rows = hunts.search(req.ctx.user,
        from: strOrNull(q['from']), to: strOrNull(q['to']), characterId: toIntOrNull(q['character_id']));
    return json([
      for (final h in rows)
        () {
          final p = huntParts(h);
          return {...h, 'fragment_income': p.fragmentIncome, 'total': p.total};
        }(),
    ]);
  }

  Future<Response> _add(Request req) async {
    final uid = req.ctx.user;
    final h = _snapshot(uid, _clean(uid, await body(req)));
    h['date'] ??= isoDate(todayKst());
    h['user_id'] = uid;
    return json({'id': hunts.insert(h)});
  }

  /// 사냥 타이머 시작 — 시작 메소만 받아두고, 끝낼 때 종료 메소로 계산.
  Future<Response> _start(Request req) async {
    final uid = req.ctx.user, b = await body(req);
    final now = nowKst();
    final id = hunts.insert({
      'user_id': uid,
      'character_id': chars.own(uid, b['character_id']) != null ? toInt(b['character_id']) : null,
      'date': isoDate(now),
      'place': strOrNull(b['place']),
      'meso_start': toIntOrNull(b['meso_start']),
      'started_at': isoKst(now),
      'status': 'running',
    });
    return json({'id': id});
  }

  /// 타이머만 멈춘다 (시간 확정). 메소·조각은 그 다음에 적고 저장.
  Response _end(Request req, String id) {
    hunts.end(req.ctx.user, pathInt(id), nowKstIso());
    return ok();
  }

  /// 실수로 종료했을 때 타이머 다시 켜기 (처음 시작 시각부터 계산).
  Response _resume(Request req, String id) {
    hunts.resume(req.ctx.user, pathInt(id));
    return ok();
  }

  Future<Response> _stop(Request req, String id) async {
    final uid = req.ctx.user, hid = pathInt(id), b = await body(req);
    final row = hunts.find(uid, hid);
    if (row == null || row['status'] != 'running') throw ApiError('진행 중인 사냥이 아니에요', 404);
    final started = parseKst(row['started_at']) ?? nowKst();
    final ended = parseKst(row['ended_at']) ?? nowKst();
    final m = roundHalfEven(ended.difference(started).inMilliseconds / 60000);
    final minutes = m < 1 ? 1 : m;
    final mesoEnd = toIntOrNull(b['meso_end']);
    var meso = toIntOrNull(b['meso']);
    if (meso == null && mesoEnd != null && row['meso_start'] != null) meso = mesoEnd - (row['meso_start'] as int);
    final snap = _snapshot(uid, {});
    hunts.update(uid, hid, {
      'status': 'done',
      'minutes': truthy(b['minutes']) ? toInt(b['minutes']) : minutes,
      'meso_end': mesoEnd,
      'meso': meso,
      'fragments': toIntOrNull(b['fragments']),
      'extra': toIntOrNull(b['extra']),
      'fragments_sold': truthy(b['fragments_sold']) ? 1 : 0,
      'fragment_price': snap['fragment_price'],
      'fragment_fee': snap['fragment_fee'],
      'note': strOrNull(b['note']),
    });
    return ok();
  }

  Future<Response> _edit(Request req, String id) async {
    final uid = req.ctx.user;
    final h = _clean(uid, await body(req));
    if (h.isEmpty) throw ApiError('바꿀 항목이 없어요');
    hunts.update(uid, pathInt(id), h);
    return ok();
  }

  Response _delete(Request req, String id) {
    hunts.delete(req.ctx.user, pathInt(id));
    return ok();
  }
}
