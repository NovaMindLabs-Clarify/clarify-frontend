import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../core/config.dart';
import '../core/log.dart';

/// Проверка, вышла ли новая версия десктопного приложения.
///
/// Почему это появилось ДО первого релиза, а не после. Приложение на Windows —
/// скомпилированный бинарник: подменить в нём код на лету, как в вебе, нельзя,
/// любое обновление означает замену файлов на диске. Само по себе это решаемо
/// (ставится оно в папку пользователя, без прав администратора), но узнать
/// О ТОМ, ЧТО ОБНОВЛЕНИЕ ВЫШЛО, приложение может только само.
///
/// Значит, проверка обязана быть уже ВНУТРИ той сборки, которую раздали. Если
/// выпустить первую версию без неё, до первой партии пользователей никакое
/// обновление не доедет: их придётся ловить руками и просить переустановить.
/// Скачивание и подмену файлов доделаем позже — а вот эта часть должна уехать
/// в первом же релизе, иначе поздно.
class UpdateInfo {
  /// Версия на сервере.
  final String version;

  /// Куда идти за ней. Пока это ссылка на установщик; когда появится
  /// обновлятор, он будет качать по ней же.
  final String url;

  /// Что изменилось — короткой строкой, для баннера.
  final String notes;

  /// Работать на текущей версии больше нельзя (сломанный протокол, отозванный
  /// ключ). Тогда предложение обновиться перестаёт быть предложением.
  final bool required;

  const UpdateInfo({
    required this.version,
    required this.url,
    required this.notes,
    required this.required,
  });
}

class UpdateService {
  UpdateService._();

  /// Текущая версия сборки. Берётся из pubspec через package_info_plus, а не
  /// из константы в коде: константу забудут обновить при релизе, и приложение
  /// начнёт считать себя устаревшим или наоборот — свежим навсегда.
  static Future<String> currentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  /// null — обновления нет, сервер не ответил или ответил мусором.
  ///
  /// Молчание во всех этих случаях намеренное: проверка обновлений не должна
  /// беспокоить человека собственными неудачами. Не смогли проверить — значит
  /// не смогли, он узнает в следующий раз.
  static Future<UpdateInfo?> check() async {
    try {
      final response = await http
          .get(Uri.parse('${AppConfig.backendBaseUrl}/app/latest-version'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;

      final data = json.decode(response.body) as Map<String, dynamic>;
      final latest = (data['version'] as String?)?.trim() ?? '';
      if (latest.isEmpty) return null;

      final current = await currentVersion();
      final minSupported = (data['min_supported'] as String?)?.trim() ?? '';

      if (compareVersions(latest, current) <= 0) return null;

      return UpdateInfo(
        version: latest,
        url: (data['url'] as String?)?.trim() ?? '',
        notes: (data['notes'] as String?)?.trim() ?? '',
        required: minSupported.isNotEmpty &&
            compareVersions(minSupported, current) > 0,
      );
    } catch (e) {
      logError('Проверка обновлений не удалась: $e');
      return null;
    }
  }

  /// Сравнение версий вида 1.2.3: -1 / 0 / 1.
  ///
  /// Именно почисловое, а не сравнение строк. Строки дали бы '1.10.0' < '1.9.0'
  /// — та же ловушка, на которой в этом проекте уже обожглись с датами
  /// ('31.08.2026' > '05.09.2026'), только тут она сработала бы ровно на
  /// десятом релизе и выглядела бы как «обновления перестали приходить».
  static int compareVersions(String a, String b) {
    List<int> parts(String v) => v
        .split('+')
        .first
        .split('.')
        .map((p) => int.tryParse(p.trim()) ?? 0)
        .toList();

    final pa = parts(a);
    final pb = parts(b);
    for (var i = 0; i < (pa.length > pb.length ? pa.length : pb.length); i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x > y ? 1 : -1;
    }
    return 0;
  }
}
