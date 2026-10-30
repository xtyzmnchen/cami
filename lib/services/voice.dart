import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

class Voice {
  static final _tts = FlutterTts();
  static var _ready = false;

  static Future<void> say(String text) async {
    if (kIsWeb) return;
    try {
      if (!_ready) {
        await _tts.setLanguage('zh-CN');
        await _tts.setSpeechRate(0.46);
        _ready = true;
      }
      await _tts.stop();
      await _tts.speak(text);
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
