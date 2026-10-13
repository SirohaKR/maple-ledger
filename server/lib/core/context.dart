// 서버 전체가 같이 쓰는 것(DB, 설정, 넥슨 클라이언트 만들기)과 요청마다의 사용자 정보.
import 'dart:io';

import 'package:shelf/shelf.dart';

import '../nexon/nexon_client.dart';
import 'db.dart';
import 'http.dart';

class Config {
  final String dbPath;
  final int port;
  final String webDir; // 웹 화면 파일 폴더
  final String changelogPath; // 업데이트 내역 초안

  Config({required this.dbPath, required this.port, required this.webDir, required this.changelogPath});

  factory Config.fromEnv() {
    final env = Platform.environment;
    return Config(
      dbPath: env['DB_PATH'] ?? 'data/ledger.db',
      port: int.tryParse(env['PORT'] ?? '') ?? 5000,
      webDir: env['WEB_DIR'] ?? 'web',
      changelogPath: env['CHANGELOG_PATH'] ?? 'CHANGELOG.md',
    );
  }
}

/// 서버 전체 공용.
class AppContext {
  final Db db;
  final Config config;

  /// 넥슨 클라이언트 만들기 (테스트에서는 가짜로 바꿔 끼운다).
  final NexonClient Function(String apiKey) nexonFor;

  AppContext({required this.db, required this.config, NexonClient Function(String apiKey)? nexonFor})
      : nexonFor = nexonFor ?? ((k) => NexonClient(k));
}

/// 요청 한 번의 사용자 (로그인 안 했으면 uid가 null).
class Ctx {
  final int? uid;
  final bool isAdmin;
  const Ctx(this.uid, this.isAdmin);

  int get user => uid ?? (throw ApiError('로그인이 필요해요', 401));

  void requireAdmin() {
    if (!isAdmin) throw ApiError('관리자만 할 수 있어요', 403);
  }
}

extension RequestCtx on Request {
  Ctx get ctx => context['ctx'] as Ctx? ?? const Ctx(null, false);
}
