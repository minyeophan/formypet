import 'dart:convert';

String? newPasswordError(String value) {
  if (value.trim().isEmpty || value.runes.length < 8) {
    return '비밀번호는 8자 이상 입력해 주세요.';
  }
  if (utf8.encode(value).length > 72) {
    return '비밀번호는 UTF-8 기준 72바이트 이하로 입력해 주세요.';
  }
  return null;
}
