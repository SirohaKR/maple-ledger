// 업데이트 내역 API — CHANGELOG.md(초안)를 관리자가 불러와 다듬어서 [게시]한 것만 길드원에게 보인다.
import 'package:shared/shared.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../core/context.dart';
import '../../core/http.dart';
import 'changelog_repository.dart';

class ChangelogRoutes {
  final ChangelogRepository repo;
  ChangelogRoutes(AppContext app) : repo = ChangelogRepository(app.db, app.config.changelogPath);

  void register(Router r) {
    // 로그인 전에도 부를 수 있게 /api/auth/ 아래에 둔다
    r.get('/api/auth/version', (Request req) {
      final posts = repo.published();
      return json({'version': posts.isEmpty ? '' : posts.first['version'], 'posts': posts});
    });
    r.get('/api/admin/changelog', (Request req) {
      req.ctx.requireAdmin();
      return json(_adminList());
    });
    r.put('/api/admin/changelog/<version>', _put);
    r.delete('/api/admin/changelog/<version>', (Request req, String version) {
      req.ctx.requireAdmin();
      repo.delete(Uri.decodeComponent(version)); // 게시 취소 + 저장한 문구 삭제 (초안은 그대로)
      return json(_adminList());
    });
  }

  List<Map<String, Object?>> _adminList() {
    final posts = repo.allPosts();
    final drafts = {for (final d in repo.drafts()) d['version'] as String: d};
    final versions = {...posts.keys, ...drafts.keys}.toList()..sort((a, b) => compareVersions(b, a));
    return [
      for (final v in versions)
        {
          'version': v,
          'draft': drafts[v], // CHANGELOG.md 초안 (없으면 관리자가 직접 만든 버전)
          'post': posts[v], // 저장/게시된 내용 (없으면 아직 손 안 댐)
          'status': posts[v] == null
              ? 'draft'
              : posts[v]!['hidden'] == 1
                  ? 'hidden'
                  : posts[v]!['published'] == 1
                      ? 'published'
                      : 'saved',
          'draft_changed': posts[v] != null && drafts[v] != null && drafts[v]!['body'] != posts[v]!['draft_base'],
        }
    ];
  }

  Future<Response> _put(Request req, String rawVersion) async {
    req.ctx.requireAdmin();
    final version = Uri.decodeComponent(rawVersion);
    if (!RegExp(r'^v[\w.]+$').hasMatch(version)) throw ApiError('버전은 v1.3 같은 형식으로 써 주세요');
    final b = await body(req);
    final row = repo.find(version) ??
        {'version': version, 'date': isoDate(todayKst()), 'body': '', 'published': 0, 'hidden': 0};
    for (final k in ['date', 'body']) {
      if (b.containsKey(k)) row[k] = (b[k] ?? '').toString().trim();
    }
    for (final k in ['published', 'hidden']) {
      if (b.containsKey(k)) row[k] = truthy(b[k]) ? 1 : 0;
    }
    repo.save(row);
    return json(_adminList());
  }
}
