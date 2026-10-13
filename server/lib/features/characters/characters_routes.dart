// 캐릭터 API — 내 캐릭터 목록, 넥슨 계정에서 불러오기, 이름으로 추가, 갱신, 순서, 삭제, 보스 프리셋.
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../core/context.dart';
import '../../core/http.dart';
import '../../core/settings_store.dart';
import 'characters_repository.dart';

class CharactersRoutes {
  final AppContext app;
  final CharactersRepository chars;
  final SettingsStore settings;

  CharactersRoutes(this.app)
      : chars = CharactersRepository(app.db),
        settings = SettingsStore(app.db);

  void register(Router r) {
    r.get('/api/characters', _list);
    r.get('/api/nexon/characters', _fromNexon);
    r.post('/api/characters', _add);
    r.post('/api/characters/refresh', _refresh);
    r.put('/api/characters/<id>', _edit);
    r.delete('/api/characters/<id>', _delete);
    r.put('/api/characters/<id>/preset', _preset);
  }

  Response _list(Request req) {
    final uid = req.ctx.user;
    final presets = chars.presets(uid);
    return json([for (final c in chars.search(uid)) {...c, 'preset': presets[c['id']] ?? []}]);
  }

  /// 내 넥슨 계정의 전체 캐릭터 (이미 등록했는지, 다른 사람이 등록했는지 표시).
  Future<Response> _fromNexon(Request req) async {
    final uid = req.ctx.user;
    final owners = chars.owners();
    final list = await app.nexonFor(settings.apiKey(uid)).accountCharacters();
    list.sort((a, b) {
      final w = '${a['world'] ?? ''}'.compareTo('${b['world'] ?? ''}');
      return w != 0 ? w : (toInt(b['level'])).compareTo(toInt(a['level']));
    });
    return json([
      for (final c in list)
        {...c, 'tracked': owners[c['ocid']] == uid, 'taken': owners.containsKey(c['ocid']) && owners[c['ocid']] != uid},
    ]);
  }

  /// 넥슨 목록에서 고른 캐릭터들(ocids)이나 이름(name)으로 추가하고 이미지까지 받아온다.
  Future<Response> _add(Request req) async {
    final uid = req.ctx.user, b = await body(req);
    final nexon = app.nexonFor(settings.apiKey(uid));
    final added = <Object?>[];
    for (final ocid in (b['ocids'] as List? ?? [])) {
      final info = {...await nexon.characterBasic('$ocid'), 'ocid': '$ocid'};
      chars.upsert(uid, info);
      added.add(info['name']);
    }
    final name = strOrNull(b['name']);
    if (name != null) {
      final ocid = await nexon.findOcid(name) ?? (throw ApiError('$name: 캐릭터를 찾지 못했어요', 502));
      final info = {...await nexon.characterBasic(ocid), 'ocid': ocid};
      chars.upsert(uid, info);
      added.add(info['name']);
    }
    return json({'added': added});
  }

  Future<Response> _refresh(Request req) async {
    final uid = req.ctx.user;
    final nexon = app.nexonFor(settings.apiKey(uid));
    final rows = chars.searchWithOcid(uid);
    for (final r in rows) {
      chars.upsert(uid, {...await nexon.characterBasic(r['ocid'] as String), 'ocid': r['ocid']});
    }
    return json({'refreshed': rows.length});
  }

  Future<Response> _edit(Request req, String id) async {
    final b = await body(req);
    if (b.containsKey('sort')) chars.setSort(req.ctx.user, pathInt(id), toInt(b['sort']));
    return ok();
  }

  Response _delete(Request req, String id) {
    chars.delete(req.ctx.user, pathInt(id));
    return ok();
  }

  /// 이 캐릭터가 매주 도는 보스 목록 전체를 교체.
  Future<Response> _preset(Request req, String id) async {
    final b = await body(req);
    final c = chars.own(req.ctx.user, id) ?? (throw ApiError('내 캐릭터가 아니에요', 404));
    chars.replacePreset(c['id'] as int, [for (final it in (b['items'] as List? ?? [])) Map<String, Object?>.from(it as Map)]);
    return ok();
  }
}
