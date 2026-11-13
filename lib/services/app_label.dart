import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 同步桌面图标下的 App 显示名（Android 可跟应用内语言切换）。
class AppLabel {
  static const _channel = MethodChannel('com.cami.day.cami/app_label');

  static Future<void> apply(String localeCode) async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<void>('setLocale', localeCode == 'en' ? 'en' : 'zh');
    } catch (_) {
      // iOS 不支持运行时改图标名；无 handler 时忽略。
    }
  }
}
