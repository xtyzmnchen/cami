import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

final _picker = ImagePicker();

Future<List<int>?> capturePhoto() async {
  await Permission.camera.request();
  final file = await _picker.pickImage(source: ImageSource.camera, imageQuality: 72);
  if (file == null) return null;
  return file.readAsBytes();
}

Future<List<int>?> captureVideo() async {
  await Permission.camera.request();
  await Permission.microphone.request();
  final file = await _picker.pickVideo(
    source: ImageSource.camera,
    maxDuration: const Duration(minutes: 2),
  );
  if (file == null) return null;
  return file.readAsBytes();
}

class ClipRecorder {
  final _recorder = AudioRecorder();
  String? _path;

  Future<bool> start() async {
    final allowed = await _recorder.hasPermission();
    if (!allowed) return false;
    final dir = await getTemporaryDirectory();
    _path = '${dir.path}/cami-note-${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: _path!,
    );
    return true;
  }

  Future<List<int>?> stop() async {
    try {
      final path = await _recorder.stop() ?? _path;
      _path = null;
      if (path == null || path.isEmpty) return null;
      return XFile(path).readAsBytes();
    } catch (_) {
      _path = null;
      return null;
    }
  }

  Future<void> dispose() => _recorder.dispose();
}
