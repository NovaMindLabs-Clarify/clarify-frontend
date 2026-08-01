import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Веб — `record` игнорирует path при старте записи и возвращает blob-URL
/// из stop(). Читаем байты через обычный http.get (blob: URL читается тем
/// же fetch-запросом, что и обычный сетевой ресурс, в пределах той же
/// страницы) — не требует отдельного dart:js_interop, в отличие от
/// push_registration_web.dart.
Future<String> prepareRecordingPath() async => 'web-recording';

Future<Uint8List> readRecordedBytes(String path) async {
  final response = await http.get(Uri.parse(path));
  return response.bodyBytes;
}
