// 웹 화면 — web/index.html과 web/static/ (Flutter 앱이 생기기 전까지 쓰는 기존 화면).
// 정적 파일이 바뀌면 주소(?v=)도 바뀌게 해서 업데이트 후 예전 화면이 브라우저에 남지 않게 한다.
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';

import '../../core/context.dart';

class WebRoutes {
  final String dir;
  late final String version = _version();
  late final Handler _static = createStaticHandler(dir);

  WebRoutes(AppContext app) : dir = app.config.webDir;

  /// 정적 파일 중 가장 최근에 바뀐 시각 (초).
  String _version() {
    final files = Directory(p.join(dir, 'static')).listSync(recursive: true).whereType<File>();
    final latest = files.fold<int>(0, (a, f) => f.lastModifiedSync().millisecondsSinceEpoch > a ? f.lastModifiedSync().millisecondsSinceEpoch : a);
    return '${latest ~/ 1000}';
  }

  void register(Router r) {
    r.get('/', _index);
    r.get('/static/<path|.*>', _file);
  }

  Response _index(Request req) {
    final html = File(p.join(dir, 'index.html')).readAsStringSync().replaceAll('{{v}}', version);
    return Response.ok(html, headers: {'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-cache'});
  }

  /// css/common.css가 @import로 부르는 파일엔 ?v=가 안 붙어서, 매번 바뀌었는지 확인하게 한다.
  Future<Response> _file(Request req, String path) async {
    final res = await _static(req); // 주소 static/... 그대로 web/static/... 파일
    return res.change(headers: {'cache-control': 'no-cache'});
  }
}
