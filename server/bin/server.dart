// 서버 시작점 — `dart run bin/server.dart` (도커에서는 컴파일한 실행 파일).
// 환경 변수: PORT(기본 5000), DB_PATH(기본 data/ledger.db), WEB_DIR(기본 web), CHANGELOG_PATH(기본 CHANGELOG.md)
import 'dart:io';

import 'package:server/app.dart';
import 'package:server/core/context.dart';
import 'package:server/core/db.dart';
import 'package:server/jobs/jobs.dart';
import 'package:shelf/shelf_io.dart' as io;

Future<void> main() async {
  final config = Config.fromEnv();
  final app = AppContext(db: Db.open(config.dbPath), config: config);
  final handler = buildApp(app);
  final server = await io.serve(handler, InternetAddress.anyIPv4, config.port);
  print('[server] http://0.0.0.0:${server.port}  DB=${config.dbPath}');

  final jobs = Jobs(app)..start();

  // 도커가 끌 때(SIGTERM)·Ctrl+C 때 깔끔하게 닫는다
  Future<void> shutdown(ProcessSignal _) async {
    jobs.stop();
    await server.close(force: true);
    app.db.close();
    exit(0);
  }

  ProcessSignal.sigint.watch().listen(shutdown);
  if (!Platform.isWindows) ProcessSignal.sigterm.watch().listen(shutdown);
}
