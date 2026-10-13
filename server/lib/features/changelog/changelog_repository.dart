// 업데이트 내역 조회 — CHANGELOG.md 초안 읽기, 저장·게시한 글.
import 'dart:io';

import 'package:shared/shared.dart';

import '../../core/db.dart';

/// "v1.2.3" → [1, 2, 3] (버전 순서 비교용).
List<int> versionKey(String v) => RegExp(r'\d+').allMatches(v).map((m) => int.parse(m[0]!)).toList();

int compareVersions(String a, String b) {
  final x = versionKey(a), y = versionKey(b);
  for (var i = 0; i < x.length && i < y.length; i++) {
    if (x[i] != y[i]) return x[i].compareTo(y[i]);
  }
  return x.length.compareTo(y.length);
}

class ChangelogRepository {
  final Db db;
  final String draftPath;
  ChangelogRepository(this.db, this.draftPath);

  /// CHANGELOG.md → [{version, date, body}] (위에서부터 = 최신순).
  List<Map<String, Object?>> drafts() {
    final f = File(draftPath);
    if (!f.existsSync()) return [];
    final text = f
        .readAsStringSync()
        .replaceAll('\r\n', '\n') // 윈도우에서 저장한 파일도 같게
        .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
    final re = RegExp(r'^## (v[\w.]+)(?:\s*[—-]\s*([^\n]+))?$(.*?)(?=^## |(?![\s\S]))', multiLine: true, dotAll: true);
    return [
      for (final m in re.allMatches(text))
        {'version': m[1], 'date': (m[2] ?? '').trim(), 'body': m[3]!.trim()},
    ];
  }

  List<Row> published() {
    final rows = db.rows('SELECT version, date, body FROM changelog_posts WHERE published = 1 AND hidden = 0');
    rows.sort((a, b) => compareVersions(b['version'] as String, a['version'] as String));
    return rows;
  }

  Map<String, Row> allPosts() => {for (final r in db.rows('SELECT * FROM changelog_posts')) r['version'] as String: r};

  Row? find(String version) => db.one('SELECT * FROM changelog_posts WHERE version = ?', [version]);

  void save(Row row) => db.exec(
      'INSERT OR REPLACE INTO changelog_posts (version, date, body, published, hidden, updated_at) VALUES (?, ?, ?, ?, ?, ?)',
      [row['version'], row['date'], row['body'], row['published'], row['hidden'], nowKstIso()]);

  void delete(String version) => db.exec('DELETE FROM changelog_posts WHERE version = ?', [version]);
}
