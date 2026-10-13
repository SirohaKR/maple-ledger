// 설정 저장소 — 모두가 같이 쓰는 설정(settings)과 사람별 설정(user_settings).
import 'db.dart';

/// 사람마다 따로 갖는 설정의 기본값.
const defaultUserSettings = {
  'sync_interval': '30', // 보스 자동 체크 주기(분). 0 = 끔
  'fragment_price': '5840000', // 솔 에르다 조각 1개 시세 (사냥 기록에 저장 시점 값으로 고정됨)
  'fragment_fee': '5', // 경매장 판매 수수료(%)
  'starforce_discount': '0', // MVP·PC방 스타포스 할인(%) — 17성 미만에만
  'enhance_backfill_days': '30', // 강화 기록을 처음 불러올 때 거슬러 올라갈 일수
};

/// 위 + 아래 키는 사람별, 나머지(공지 감시 단어, 초대 코드 등)는 모두가 같이 쓴다.
final userKeys = {
  ...defaultUserSettings.keys,
  'nexon_api_key', 'sync_result', 'last_sync', 'last_daily', 'last_enhance_sync', 'ledger_start',
};

class SettingsStore {
  final Db db;
  SettingsStore(this.db);

  /// 같이 쓰는 설정 + 기본값 + 내 설정 (내 것이 우선).
  Map<String, String?> all(int? uid) {
    final s = <String, String?>{
      for (final r in db.rows('SELECT key, value FROM settings'))
        if (!userKeys.contains(r['key']) && r['key'] != 'secret_key') r['key'] as String: r['value'] as String?,
    };
    s.addAll(defaultUserSettings);
    if (uid != null) {
      for (final r in db.rows('SELECT key, value FROM user_settings WHERE user_id = ?', [uid])) {
        s[r['key'] as String] = r['value'] as String?;
      }
    }
    return s;
  }

  String? get(int? uid, String key) => all(uid)[key];

  void set(int? uid, String key, String? value) {
    if (userKeys.contains(key)) {
      db.exec('INSERT OR REPLACE INTO user_settings VALUES (?, ?, ?)', [uid, key, value]);
    } else {
      db.exec('INSERT OR REPLACE INTO settings VALUES (?, ?)', [key, value]);
    }
  }

  /// 모두가 같이 쓰는 설정 하나 (초대 코드 같은 것).
  String? global(String key) => db.scalar('SELECT value FROM settings WHERE key = ?', [key]) as String?;

  String apiKey(int uid) => get(uid, 'nexon_api_key') ?? '';

  /// 장부 시작일. 통계의 지출은 이 날부터만 센다.
  /// 직접 정하지 않았으면: 정식 버전 전에 가입한 사람은 [spendCountFrom], 그 뒤 가입한 사람은 가입한 날
  /// (가입 전 강화 기록이 지출에 섞이지 않게). 어느 경우든 [spendCountFrom]보다 앞으로는 못 간다.
  String ledgerStart(int uid) {
    var v = get(uid, 'ledger_start') ?? '';
    if (v.isEmpty) {
      final created = db.scalar('SELECT created_at FROM users WHERE id = ?', [uid]) as String? ?? '';
      final joined = created.length >= 10 ? created.substring(0, 10) : created;
      v = joined.compareTo(_launchDay) > 0 ? joined : spendCountFrom;
    }
    return v.compareTo(spendCountFrom) > 0 ? v : spendCountFrom;
  }
}

/// 대시보드 지출을 세기 시작하는 날 (모두 공통). 이 날 이전 강화 비용·지출은 통계에 안 들어간다.
const spendCountFrom = '2026-10-11';

/// 정식 버전(v1.0) 날. 이 날까지 가입한 사람은 장부 시작일 기본값이 [spendCountFrom].
const _launchDay = '2026-10-13';
