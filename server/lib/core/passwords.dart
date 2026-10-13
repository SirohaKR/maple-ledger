// 비밀번호 해시 — Python(werkzeug) 버전에서 만든 해시도 그대로 확인할 수 있게 같은 형식을 쓴다.
// 형식: "방식$소금$해시(16진수)"
//   scrypt:32768:8:1$abc...$...   (예전 Python 기본값)
//   pbkdf2:sha256:600000$abc...$...
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

const _saltChars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
final _rand = Random.secure();

String _hex(Uint8List b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

Uint8List _pbkdf2(String password, String salt, int iterations, int length) {
  final d = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
    ..init(Pbkdf2Parameters(Uint8List.fromList(utf8.encode(salt)), iterations, length));
  return d.process(Uint8List.fromList(utf8.encode(password)));
}

Uint8List _scrypt(String password, String salt, int n, int r, int p, int length) {
  final s = Scrypt()..init(ScryptParameters(n, r, p, length, Uint8List.fromList(utf8.encode(salt))));
  return s.process(Uint8List.fromList(utf8.encode(password)));
}

/// 새 비밀번호 해시 — Python(werkzeug) 기본값과 같은 scrypt (N=32768, r=8, p=1).
String hashPassword(String password) {
  final salt = List.generate(16, (_) => _saltChars[_rand.nextInt(_saltChars.length)]).join();
  return 'scrypt:32768:8:1\$$salt\$${_hex(_scrypt(password, salt, 32768, 8, 1, 64))}';
}

/// 저장된 해시와 비밀번호가 맞는지.
bool checkPassword(String stored, String password) {
  final parts = stored.split(r'$');
  if (parts.length != 3) return false;
  final method = parts[0].split(':'), salt = parts[1], want = parts[2];
  String got;
  if (method[0] == 'scrypt') {
    final n = int.tryParse(method.length > 1 ? method[1] : '') ?? 32768;
    final r = int.tryParse(method.length > 2 ? method[2] : '') ?? 8;
    final p = int.tryParse(method.length > 3 ? method[3] : '') ?? 1;
    got = _hex(_scrypt(password, salt, n, r, p, 64));
  } else if (method[0] == 'pbkdf2' && (method.length < 2 || method[1] == 'sha256')) {
    final it = int.tryParse(method.length > 2 ? method[2] : '') ?? 600000;
    got = _hex(_pbkdf2(password, salt, it, 32));
  } else {
    return false;
  }
  // 시간 차로 정답을 추측하지 못하게 끝까지 비교
  if (got.length != want.length) return false;
  var diff = 0;
  for (var i = 0; i < got.length; i++) {
    diff |= got.codeUnitAt(i) ^ want.codeUnitAt(i);
  }
  return diff == 0;
}

/// 임의 문자열 (초대 코드·세션 토큰).
String randomToken([int bytes = 24]) =>
    base64Url.encode(List.generate(bytes, (_) => _rand.nextInt(256))).replaceAll('=', '');
