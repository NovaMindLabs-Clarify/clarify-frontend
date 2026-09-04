import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Локальный кэш приложения: шифрование на диске + правильная папка.
///
/// Было (A7 в docs/AUDIT_2026-09-04.md): боксы Hive лежали НЕЗАШИФРОВАННЫМИ
/// в «Документах» пользователя. Любая программа, запущенная под тем же
/// пользователем, читала все задачи обычным чтением файла — это не теория,
/// именно так 04.09.2026 разбирались с «дублированием» задач, читая
/// tasks_cache.hive посторонним процессом. Для планировщика с рабочими
/// задачами это чувствительно.
///
/// Стало: AES-шифрование (`HiveAesCipher`), ключ — в защищённом хранилище ОС
/// (на Windows это DPAPI через flutter_secure_storage), сами боксы — в
/// `getApplicationSupportDirectory()`, служебной папке приложения, а не в
/// пользовательских «Документах».
///
/// На вебе всё это неприменимо: там Hive живёт в IndexedDB, файла на диске
/// нет, а секретного места для ключа в браузере не существует — веб-ветка
/// открывает боксы как раньше.
const List<String> kClarifyBoxes = ['tasks_cache', 'settings', 'pending_ops'];

const String _kCipherKeyName = 'clarify_hive_cipher_key_v1';

/// Инициализирует Hive и открывает все боксы приложения.
///
/// Единственная точка открытия боксов — вызывать до `runApp`. Остальной код
/// работает через `Hive.box(...)` и о шифровании ничего не знает.
Future<void> openClarifyBoxes() async {
  if (kIsWeb) {
    await Hive.initFlutter();
    for (final name in kClarifyBoxes) {
      await Hive.openBox(name);
    }
    return;
  }

  final Directory support = await getApplicationSupportDirectory();
  final Directory boxesDir = Directory(p.join(support.path, 'hive'));
  await boxesDir.create(recursive: true);

  final HiveAesCipher cipher = HiveAesCipher(await _cipherKey());

  final Directory legacyDir = await getApplicationDocumentsDirectory();
  await _migrateLegacyBoxes(legacyDir: legacyDir, targetDir: boxesDir, cipher: cipher);

  Hive.init(boxesDir.path);
  for (final name in kClarifyBoxes) {
    await _openEncrypted(name, boxesDir, cipher);
  }
}

/// Открывает бокс, а если файл не читается этим ключом — заводит его заново.
///
/// Ключ может пропасть только вместе с хранилищем ОС (переустановка системы,
/// смена профиля, сброс учётных данных). В этом случае старый файл не
/// расшифровать в принципе — держаться за него незачем, а приложение,
/// падающее на старте без единого кадра, хуже пустого кэша: задачи всё равно
/// приедут с сервера при первой синхронизации.
Future<void> _openEncrypted(String name, Directory dir, HiveAesCipher cipher) async {
  try {
    await Hive.openBox(name, encryptionCipher: cipher);
  } catch (e) {
    debugPrint('[hive] бокс $name не открылся ($e) — пересоздаём');
    await Hive.deleteBoxFromDisk(name, path: dir.path);
    await Hive.openBox(name, encryptionCipher: cipher);
  }
}

Future<Uint8List> _cipherKey() async {
  const storage = FlutterSecureStorage(
    // Без этого на Android ключ жил бы в обычных SharedPreferences.
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  try {
    final String? stored = await storage.read(key: _kCipherKeyName);
    if (stored != null) {
      final Uint8List key = base64Url.decode(stored);
      if (key.length == 32) return key;
      debugPrint('[hive] сохранённый ключ неверной длины — генерируем новый');
    }
  } catch (e) {
    debugPrint('[hive] не удалось прочитать ключ из хранилища ОС ($e) — генерируем новый');
  }

  final Uint8List key = Uint8List.fromList(Hive.generateSecureKey());
  await storage.write(key: _kCipherKeyName, value: base64UrlEncode(key));
  return key;
}

/// Разовый перенос старых незашифрованных боксов из «Документов».
///
/// Работает ровно один раз на устройство: как только в новой папке появился
/// файл бокса, старый больше не рассматривается. Старый файл после переноса
/// удаляется — иначе смысл шифрования теряется, открытая копия осталась бы
/// лежать рядом.
Future<void> _migrateLegacyBoxes({
  required Directory legacyDir,
  required Directory targetDir,
  required HiveAesCipher cipher,
}) async {
  for (final name in kClarifyBoxes) {
    final File legacyFile = File(p.join(legacyDir.path, '$name.hive'));
    final File targetFile = File(p.join(targetDir.path, '$name.hive'));
    if (!legacyFile.existsSync() || targetFile.existsSync()) continue;

    try {
      Hive.init(legacyDir.path);
      final Box legacy = await Hive.openBox(name);
      final Map<dynamic, dynamic> data = Map<dynamic, dynamic>.from(legacy.toMap());
      await legacy.close();

      Hive.init(targetDir.path);
      final Box migrated = await Hive.openBox(name, encryptionCipher: cipher);
      await migrated.putAll(data);
      await migrated.close();

      await legacyFile.delete();
      final File legacyLock = File(p.join(legacyDir.path, '$name.lock'));
      if (legacyLock.existsSync()) await legacyLock.delete();
      debugPrint('[hive] бокс $name перенесён в ${targetDir.path} и зашифрован');
    } catch (e) {
      // Перенос — не повод не запуститься. Не получилось перенести старые
      // данные — начинаем с пустого зашифрованного бокса, задачи приедут с
      // сервера. Старый файл при этом НЕ удаляем: он может ещё пригодиться
      // для ручного разбора.
      debugPrint('[hive] не удалось перенести бокс $name: $e');
    }
  }
}
