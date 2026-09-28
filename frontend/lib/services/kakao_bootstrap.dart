import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

class KakaoBootstrap {
  static Future<void>? _initialization;
  static Future<void> ensureReady() => _initialization ??= _initialize();
  static Future<void> _initialize() async {
    const key = String.fromEnvironment('KAKAO_NATIVE_APP_KEY');
    if (key.isEmpty) throw StateError('카카오 로그인 설정을 확인해 주세요.');
    await KakaoSdk.init(nativeAppKey: key);
  }
}
