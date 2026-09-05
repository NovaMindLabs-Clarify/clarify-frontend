import 'dart:convert';

import 'package:hive/hive.dart';

/// Локальный список задач: то, что показано на экране, и то, что лежит в Hive.
///
/// Выделено из TaskService ради проверяемости. Сам сервис намертво завязан на
/// живой клиент Supabase, и из-за этого две вещи оставались без тестов:
///   * B7 — задача, которую сервер отклонил, должна исчезать с экрана, а при
///     сетевой ошибке, наоборот, оставаться (уйдёт из очереди отложенных);
///   * B2 — точечное применение realtime-события вместо перечитывания всего.
/// Обе логики — про список в памяти, а не про сеть, поэтому здесь они без
/// Supabase вообще: на входе обычные Map, а не типы клиента.
class TaskCache {
  final Box _box;
  List<Map<String, dynamic>> _tasks = [];

  TaskCache(this._box);

  /// Копия списка — Flutter сравнивает списки по ссылке, и без копии экран не
  /// заметил бы изменения.
  List<Map<String, dynamic>> get tasks => List<Map<String, dynamic>>.from(_tasks);

  int get length => _tasks.length;

  /// Подхватывает содержимое из Hive, если в памяти пусто (холодный старт).
  List<Map<String, dynamic>> loadFromDiskIfEmpty() {
    if (_tasks.isEmpty) {
      final raw = _box.get('all_tasks');
      if (raw != null) {
        _tasks = List<Map<String, dynamic>>.from(json.decode(raw));
      }
    }
    return tasks;
  }

  /// Полностью заменяет содержимое — результат fetchTasks.
  void replaceAll(List<Map<String, dynamic>> rows) {
    _tasks = List<Map<String, dynamic>>.from(rows);
    _persist();
  }

  /// Оптимистично добавленная задача — показывается до ответа сервера.
  void addOptimistic(Map<String, dynamic> row) {
    _tasks.add(row);
    _persist();
  }

  /// Заменяет временную строку на настоящую, пришедшую с сервера.
  void confirmOptimistic(int tempId, Map<String, dynamic> serverRow) {
    final index = _tasks.indexWhere((t) => t['id'] == tempId);
    if (index == -1) {
      _tasks.add(serverRow);
    } else {
      _tasks[index] = serverRow;
    }
    _persist();
  }

  /// Убирает оптимистичную запись (B7).
  ///
  /// Только когда сервер ОТКАЗАЛ. При сетевой ошибке запись должна остаться:
  /// она уйдёт из очереди отложенных операций, когда связь вернётся.
  void removeOptimistic(int tempId) {
    _tasks.removeWhere((t) => t['id'] == tempId);
    _persist();
  }

  /// Применяет одно изменение из realtime-события (B2).
  ///
  /// [eventType] — 'INSERT' | 'UPDATE' | 'DELETE' в том виде, в каком его
  /// присылает Postgres. Возвращает false, если применить нельзя и вызывающему
  /// коду нужно перечитать всё целиком: «применить неправильно» хуже, чем
  /// «перечитать лишний раз».
  bool applyChange({required String eventType, required Map<String, dynamic> record}) {
    final int? id = _idOf(record['id']);
    if (id == null) return false;

    switch (eventType.toUpperCase()) {
      case 'DELETE':
        _removeById(id);

      case 'INSERT':
      case 'UPDATE':
        // Задача уехала в корзину (C6) — для списка это то же самое, что
        // удаление: событие приходит как UPDATE, но показывать её нельзя.
        if (record['deleted_at'] != null) {
          _removeById(id);
          break;
        }
        final row = Map<String, dynamic>.from(record);
        final index = _tasks.indexWhere((t) => _idOf(t['id']) == id);
        if (index == -1) {
          _tasks.add(row);
        } else {
          _tasks[index] = row;
        }

      default:
        return false;
    }

    _persist();
    return true;
  }

  /// id как число, откуда бы оно ни пришло.
  ///
  /// Payload проходит через JSON, и закладываться на то, что id всегда придёт
  /// числом, не стоит. Важнее другое: разбирать строку у ВХОДЯЩЕГО события, но
  /// сравнивать с уже лежащим в списке «как есть» — это половина решения.
  /// '5' == 5 в Dart даёт false, и удаление такой строки молча не срабатывало
  /// бы, оставляя задачу на экране. Поймано тестом.
  int? _idOf(dynamic raw) => raw is int ? raw : int.tryParse(raw?.toString() ?? '');

  void _removeById(int id) => _tasks.removeWhere((t) => _idOf(t['id']) == id);

  void _persist() {
    _box.put('all_tasks', json.encode(_tasks));
  }
}
