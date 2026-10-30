import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

final memoryMedia = <String, Uint8List>{};

Future<String> saveMediaBytes(String filename, List<int> bytes) async {
  memoryMedia[filename] = Uint8List.fromList(bytes);
  return filename;
}

Future<List<int>?> readMediaBytes(String path) async => memoryMedia[path];

Future<void> deleteMediaFile(String path, String storedName) async {
  memoryMedia.remove(path);
  memoryMedia.remove(storedName);
}

Future<void> pruneOrphanMedia(Set<String> keepNames) async {
  memoryMedia.removeWhere((key, _) => !keepNames.contains(key));
}

Future<String?> readState() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('cami_state');
}

Future<void> writeState(String value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('cami_state', value);
}

Widget mediaView({
  required String kind,
  required String path,
  required String filename,
  String? serverUrl,
  String? token,
}) {
  final bytes = memoryMedia[filename] ?? memoryMedia[path];
  final remote = (serverUrl ?? '').isNotEmpty
      ? '${serverUrl!.replaceAll(RegExp(r'/+$'), '')}/api/media/$filename?token=${Uri.encodeQueryComponent(token ?? '')}'
      : null;
  if (kind == 'photo') {
    if (bytes != null) return Image.memory(bytes, fit: BoxFit.cover);
    if (remote != null) return Image.network(remote, fit: BoxFit.cover);
  }
  if (remote != null && kind != 'photo') {
    return Center(child: Text(kind == 'video' ? '视频已在家里' : '录音已在家里'));
  }
  if (bytes != null) {
    return const Center(child: Icon(Icons.check_circle, color: Color(0xFF2F9A62)));
  }
  return const ColoredBox(
    color: Color(0xFFFFE0EC),
    child: Center(child: Icon(Icons.image_outlined)),
  );
}
