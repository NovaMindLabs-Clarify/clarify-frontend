import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:frontend/services/task_cache.dart';

/// Локальный список задач: оптимистичное создание (B7) и точечное применение
/// realtime-события (B2).
///
/// Обе логики раньше жили внутри TaskService и потому оставались без тестов:
/// сервис намертво завязан на живой клиент Supabase, подменить который нечем.
/// Вынесенные в TaskCache, они проверяются обычными данными.
void main() {
  late Directory tempDir;
  late Box box;
  late TaskCache cache;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('clarify_cache_test');
    Hive.init(tempDir.path);
  });

  setUp(() async {
    box = await Hive.openBox('tasks_cache_test_${DateTime.now().microsecondsSinceEpoch}');
    cache = TaskCache(box);
  });

  tearDown(() async {
    await box.deleteFromDisk();
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  Map<String, dynamic> task(int id, {String title = 'Задача', dynamic deletedAt}) => {
        'id': id,
        'title': title,
        'is_completed': false,
        'deleted_at': deletedAt,
      };

  List<String> titles() => cache.tasks.map((t) => t['title'] as String).toList();

  group('оптимистичное создание (B7)', () {
    test('задача показывается сразу и попадает на диск', () {
      cache.addOptimistic(task(-1, title: 'Новая'));
      expect(titles(), ['Новая']);

      final saved = List<Map<String, dynamic>>.from(json.decode(box.get('all_tasks')));
      expect(saved.single['title'], 'Новая',
          reason: 'без записи на диск задача пропала бы при перезапуске');
    });

    test('подтверждение заменяет временную строку на серверную', () {
      cache.addOptimistic(task(-1, title: 'Новая'));
      cache.confirmOptimistic(-1, {'id': 42, 'title': 'Новая', 'is_completed': false});

      expect(cache.length, 1, reason: 'не должно остаться двух копий одной задачи');
      expect(cache.tasks.single['id'], 42);
    });

    test('отказ сервера убирает задачу и из памяти, и с диска', () {
      cache.addOptimistic(task(-1, title: 'Отклонённая'));
      cache.removeOptimistic(-1);

      expect(titles(), isEmpty);
      final saved = List<Map<String, dynamic>>.from(json.decode(box.get('all_tasks')));
      expect(saved, isEmpty,
          reason: 'иначе задача-призрак вернулась бы после перезапуска приложения');
    });

    test('убирается ровно отклонённая задача, соседние не трогаются', () {
      cache.addOptimistic(task(-1, title: 'Отклонённая'));
      cache.addOptimistic(task(-2, title: 'Соседняя'));
      cache.removeOptimistic(-1);
      expect(titles(), ['Соседняя']);
    });
  });

  group('применение realtime-события (B2)', () {
    test('INSERT добавляет строку', () {
      final ok = cache.applyChange(eventType: 'INSERT', record: task(1, title: 'Пришла'));
      expect(ok, isTrue);
      expect(titles(), ['Пришла']);
    });

    test('UPDATE заменяет строку по id, не плодя дубликат', () {
      cache.applyChange(eventType: 'INSERT', record: task(1, title: 'Было'));
      cache.applyChange(eventType: 'UPDATE', record: task(1, title: 'Стало'));
      expect(titles(), ['Стало']);
    });

    test('UPDATE по неизвестному id добавляет строку', () {
      // Задача могла войти в окно загрузки только что — например, у неё
      // поменялась дата.
      cache.applyChange(eventType: 'UPDATE', record: task(7, title: 'Появилась'));
      expect(titles(), ['Появилась']);
    });

    test('DELETE убирает строку', () {
      cache.applyChange(eventType: 'INSERT', record: task(1, title: 'Уйдёт'));
      cache.applyChange(eventType: 'DELETE', record: {'id': 1});
      expect(titles(), isEmpty);
    });

    test('уход в корзину приходит как UPDATE, но убирает строку (C6)', () {
      cache.applyChange(eventType: 'INSERT', record: task(1, title: 'В корзину'));
      final ok = cache.applyChange(
        eventType: 'UPDATE',
        record: task(1, title: 'В корзину', deletedAt: '2026-09-05T10:00:00Z'),
      );
      expect(ok, isTrue);
      expect(titles(), isEmpty, reason: 'удалённая задача не должна остаться в списке');
    });

    test('событие без id не применяется — вызывающий код перечитает всё', () {
      cache.applyChange(eventType: 'INSERT', record: task(1, title: 'Живая'));
      final ok = cache.applyChange(eventType: 'UPDATE', record: {'title': 'Без id'});
      expect(ok, isFalse);
      expect(titles(), ['Живая'], reason: 'кэш не должен пострадать от непонятного события');
    });

    test('неизвестный тип события не применяется', () {
      final ok = cache.applyChange(eventType: 'TRUNCATE', record: task(1));
      expect(ok, isFalse);
      expect(cache.length, 0);
    });

    test('id строкой тоже понимается', () {
      // Postgres присылает числа, но payload проходит через JSON, и на это
      // лучше не закладываться жёстко.
      cache.applyChange(eventType: 'INSERT', record: {'id': '5', 'title': 'Строковый id'});
      cache.applyChange(eventType: 'DELETE', record: {'id': 5});
      expect(titles(), isEmpty);
    });

    test('изменения переживают перезапуск: пишутся на диск', () {
      cache.applyChange(eventType: 'INSERT', record: task(1, title: 'Сохранена'));
      final restored = TaskCache(box).loadFromDiskIfEmpty();
      expect(restored.single['title'], 'Сохранена');
    });
  });

  group('полная замена списка', () {
    test('replaceAll затирает прежнее содержимое', () {
      cache.addOptimistic(task(-1, title: 'Старое'));
      cache.replaceAll([task(1, title: 'С сервера')]);
      expect(titles(), ['С сервера']);
    });
  });
}
