import 'dart:io';
import 'dart:typed_data';

/// Десктоп (Windows) — `record` пишет во временный файл, путь обязателен.
/// Читаем байты и сразу удаляем временный файл, он больше не нужен: сама
/// расшифровка происходит на бэкенде (/ai/transcribe-voice), само аудио в
/// приложении никуда не сохраняется и не проигрывается — тот же подход, что
/// и у Telegram-бота (transcribe_voice в telegram_bot.py), который тоже не
/// хранит аудио после расшифровки.
Future<String> prepareRecordingPath() async {
  final dir = Directory.systemTemp;
  return '${dir.path}${Platform.pathSeparator}clarify_voice_${DateTime.now().microsecondsSinceEpoch}.m4a';
}

Future<Uint8List> readRecordedBytes(String path) async {
  final file = File(path);
  final bytes = await file.readAsBytes();
  try {
    await file.delete();
  } catch (_) {
    // Не критично — временный файл в системной temp-папке, ОС уберёт сама.
  }
  return bytes;
}
