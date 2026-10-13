// 넥슨 오픈 API(메이플스토리) 클라이언트 — 키는 사용자가 웹 설정에서 넣는다.
// 문서: https://openapi.nexon.com/ko/game/maplestory/
// 다른 API(유니온, 장비 …)가 필요하면 여기에 함수만 추가하면 된다.
import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:http/http.dart' as http;

class NexonError implements Exception {
  final String message;
  NexonError(this.message);
  @override
  String toString() => message;
}

typedef Json = Map<String, dynamic>;

class NexonClient {
  final String apiKey;
  final http.Client _http;
  final String base;

  NexonClient(this.apiKey, {http.Client? client, String? base})
      : _http = client ?? http.Client(),
        base = base ?? Platform.environment['NEXON_BASE'] ?? 'https://open.api.nexon.com/maplestory/v1';

  Future<Json> get(String path, [Map<String, Object?> params = const {}]) async {
    if (apiKey.isEmpty) throw NexonError('넥슨 API 키가 설정되지 않았어요. 설정 탭에서 입력해 주세요.');
    final uri = Uri.parse('$base$path').replace(queryParameters: {
      for (final e in params.entries)
        if (e.value != null) e.key: e.value.toString(),
    });
    http.Response r;
    try {
      r = await _http.get(uri, headers: {'x-nxopen-api-key': apiKey}).timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw NexonError('넥슨 API 연결 실패: 시간 초과');
    } catch (e) {
      throw NexonError('넥슨 API 연결 실패: $e');
    }
    if (r.statusCode != 200) {
      String msg;
      try {
        final err = (jsonDecode(utf8.decode(r.bodyBytes)) as Map)['error'] as Map? ?? {};
        msg = '${err['name'] ?? r.statusCode}: ${err['message'] ?? ''}';
      } catch (_) {
        msg = 'HTTP ${r.statusCode}';
      }
      throw NexonError('넥슨 API 오류 — $msg');
    }
    final d = jsonDecode(utf8.decode(r.bodyBytes));
    return d is Map ? Json.from(d) : {};
  }

  /// API 키 주인 계정의 전체 캐릭터 목록.
  Future<List<Json>> accountCharacters() async {
    final data = await get('/character/list');
    return [
      for (final acc in (data['account_list'] as List? ?? []))
        for (final c in ((acc as Map)['character_list'] as List? ?? []))
          {
            'ocid': c['ocid'],
            'name': c['character_name'],
            'world': c['world_name'],
            'job': c['character_class'],
            'level': c['character_level'],
          }
    ];
  }

  Map<String, Object?> _p(String ocid, String? date, [Map<String, Object?> extra = const {}]) =>
      {'ocid': ocid, ...extra, if (date != null && date.isNotEmpty) 'date': date};

  /// date를 주면 그날 기준 (전날 데이터는 다음날 새벽 2시부터).
  Future<Json> characterBasic(String ocid, [String? date]) async {
    final d = await get('/character/basic', _p(ocid, date));
    final rate = d['character_exp_rate'];
    return {
      'name': d['character_name'],
      'world': d['world_name'],
      'job': d['character_class'],
      'level': d['character_level'],
      'image': d['character_image'],
      'exp': d['character_exp'],
      'exp_rate': rate == null || rate == '' ? 0.0 : double.tryParse(rate.toString()),
    };
  }

  Future<int?> combatPower(String ocid, [String? date]) async {
    final d = await get('/character/stat', _p(ocid, date));
    for (final s in (d['final_stat'] as List? ?? [])) {
      if (s['stat_name'] == '전투력') {
        final v = double.tryParse('${s['stat_value'] ?? 0}');
        return v?.toInt();
      }
    }
    return null;
  }

  Future<Json> itemEquipment(String ocid) => get('/character/item-equipment', _p(ocid, null));
  Future<Json> hexamatrix(String ocid) => get('/character/hexamatrix', _p(ocid, null));
  Future<Json> skills(String ocid, String grade) =>
      get('/character/skill', _p(ocid, null, {'character_skill_grade': grade}));
  Future<Json> symbols(String ocid) => get('/character/symbol-equipment', _p(ocid, null));

  static const historyKeys = {'starforce': 'starforce_history', 'potential': 'potential_history', 'cube': 'cube_history'};

  /// 계정 전체의 강화 기록(스타포스/잠재능력 재설정/큐브) — 그날 것을 페이지 끝까지.
  Future<List<Json>> history(String kind, String date) async {
    final out = <Json>[];
    String? cursor;
    while (true) {
      final d = await get('/history/$kind', {'count': 1000, if (cursor != null) 'cursor': cursor else 'date': date});
      out.addAll((d[historyKeys[kind]] as List? ?? []).map((e) => Json.from(e as Map)));
      cursor = d['next_cursor'] as String?;
      if (cursor == null || cursor.isEmpty) return out;
    }
  }

  static const noticeKeys = {'notice': 'notice', 'notice-update': 'update_notice', 'notice-event': 'event_notice'};

  Future<List<Json>> notices(String kind) async =>
      ((await get('/$kind'))[noticeKeys[kind]] as List? ?? []).map((e) => Json.from(e as Map)).toList();

  Future<Json> noticeDetail(String kind, Object? noticeId) => get('/$kind/detail', {'notice_id': noticeId});

  /// 스케줄러(보스 완료 여부 등). 본인 계정 캐릭터만, 최대 14일 전까지.
  /// date 미지정 = 실시간. 그날 접속하지 않았으면 내용이 비어 있을 수 있다.
  Future<Json> schedulerState(String ocid, [String? date]) =>
      get('/scheduler/character-state', {'ocid': ocid, if (date != null) 'date': date});

  Future<String?> findOcid(String name) async => (await get('/id', {'character_name': name}))['ocid'] as String?;
}
