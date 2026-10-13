// HTTP 도구 — JSON 응답, 요청 본문 읽기, 오류 응답, 값 변환.
import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../nexon/nexon_client.dart';

/// 화면에 {"error": "..."}로 보여줄 오류.
class ApiError implements Exception {
  final int status;
  final String message;
  ApiError(this.message, [this.status = 400]);
  @override
  String toString() => message;
}

Response json(Object? body, {int status = 200}) => Response(
      status,
      body: jsonEncode(body, toEncodable: _encodable),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Object? _encodable(Object? o) => o is double && (o.isNaN || o.isInfinite) ? null : o.toString();

Response ok() => json({'ok': true});

/// 요청 본문(JSON). 비어 있거나 깨졌으면 빈 맵.
Future<Map<String, Object?>> body(Request req) async {
  final text = await req.readAsString();
  if (text.trim().isEmpty) return {};
  try {
    final v = jsonDecode(text);
    return v is Map ? Map<String, Object?>.from(v) : {};
  } on FormatException {
    return {};
  }
}

/// 오류를 JSON 응답으로 바꾸는 미들웨어.
Middleware errorMiddleware() => (inner) => (req) async {
      try {
        return await inner(req);
      } on ApiError catch (e) {
        return json({'error': e.message}, status: e.status);
      } on NexonError catch (e) {
        return json({'error': e.message}, status: 502);
      } catch (e, st) {
        print('[error] ${req.method} ${req.requestedUri.path}: $e\n$st');
        return json({'error': '서버 오류: $e'}, status: 500);
      }
    };

// ───── 값 변환 (화면에서 오는 값은 문자열·숫자·빈칸이 섞여 있다) ─────

int? toIntOrNull(Object? v) {
  if (v == null || v == '') return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is bool) return v ? 1 : 0;
  return int.tryParse(v.toString().trim()) ?? double.tryParse(v.toString().trim())?.toInt();
}

int toInt(Object? v, [int fallback = 0]) => toIntOrNull(v) ?? fallback;

double? toDoubleOrNull(Object? v) {
  if (v == null || v == '') return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().trim());
}

/// 파이썬의 참/거짓 판단과 비슷하게 (0, '', null, false, [] → 거짓).
bool truthy(Object? v) {
  if (v == null || v == false) return false;
  if (v is num) return v != 0;
  if (v is String) return v.isNotEmpty;
  if (v is Iterable) return v.isNotEmpty;
  if (v is Map) return v.isNotEmpty;
  return true;
}

/// 공백을 자르고, 비었으면 null.
String? strOrNull(Object? v) {
  final s = (v ?? '').toString().trim();
  return s.isEmpty ? null : s;
}

/// 주소의 숫자 부분 (/api/hunts/12 → 12).
int pathInt(String v) => int.tryParse(v) ?? (throw ApiError('잘못된 번호예요', 404));
