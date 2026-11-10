import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

class Voice {
  static final _tts = FlutterTts();
  static String? _lang;

  static Future<void> _speak(String text, String language, double rate) async {
    if (kIsWeb) return;
    if (text.trim().isEmpty) return;
    try {
      if (_lang != language) {
        await _tts.setLanguage(language);
        await _tts.setSpeechRate(rate);
        _lang = language;
      }
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
  }

  static Future<void> say(String text) => _speak(text, 'zh-CN', 0.46);

  static Future<void> sayEn(String text) => _speak(text, 'en-US', 0.42);

  /// 古诗朗诵：稍慢，并等说完再返回，方便逐句跟读。
  static Future<void> sayPoem(String text) async {
    if (kIsWeb) return;
    if (text.trim().isEmpty) return;
    try {
      if (_lang != 'zh-CN') {
        await _tts.setLanguage('zh-CN');
        _lang = 'zh-CN';
      }
      await _tts.setSpeechRate(0.36);
      await _tts.awaitSpeakCompletion(true);
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
  }

  static Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  static Future<String?> listen({String localeId = 'zh_CN'}) async {
    if (kIsWeb) return null;
    final speech = SpeechToText();
    try {
      final ok = await speech.initialize();
      if (!ok) return null;
      final result = Completer<String?>();
      await speech.listen(
        onResult: (res) {
          if (res.finalResult && !result.isCompleted) {
            result.complete(res.recognizedWords.trim());
          }
        },
        listenOptions: SpeechListenOptions(
          localeId: localeId,
          listenFor: const Duration(seconds: 8),
          pauseFor: const Duration(seconds: 2),
        ),
      );
      final text = await result.future.timeout(
        const Duration(seconds: 9),
        onTimeout: () => null,
      );
      await speech.stop();
      if (text == null || text.isEmpty) return null;
      return text;
    } catch (_) {
      return null;
    }
  }
}
