import 'dart:convert';

import 'package:http/http.dart' as http;

Future<String> toChinese(String text) async {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return trimmed;
  if (!RegExp(r'[A-Za-z]').hasMatch(trimmed)) return trimmed;
  try {
    final uri = Uri.https('api.mymemory.translated.net', '/get', {
      'q': trimmed,
      'langpair': 'en|zh-CN',
    });
    final res = await http.get(uri).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return trimmed;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final translated = (data['responseData'] as Map?)?['translatedText'] as String?;
    if (translated == null || translated.isEmpty) return trimmed;
    return translated;
  } catch (_) {
    return trimmed;
  }
}
