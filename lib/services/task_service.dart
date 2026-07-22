import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';

class TaskService {
  final Box _tasksBox = Hive.box('tasks_cache');
  RealtimeChannel? _realtimeChannel;
  
  // --- ЗАМЕНИТЬ НАЧАЛО КЛАССА И ФУНКЦИИ ДО updateTask ВКЛЮЧИТЕЛЬНО ---
  // Локальный оперативный кэш в памяти для мгновенного доступа
  List<Map<String, dynamic>> _inMemoryTasks = [];

  // --- ЗАМЕНИ ЭТУ ФУНКЦИЮ ---
  // 1. Получение локального кэша (теперь с генерацией новой ссылки!)
  List<Map<String, dynamic>> getCachedTasks() {
    if (_inMemoryTasks.isEmpty) {
      final cachedTasks = _tasksBox.get('all_tasks');
      if (cachedTasks != null) {
        _inMemoryTasks = List<Map<String, dynamic>>.from(json.decode(cachedTasks));
      }
    }
    // КРИТИЧЕСКИЙ ФИКС: Возвращаем КОПИЮ списка, чтобы Flutter понял, что данные изменились
    return List<Map<String, dynamic>>.from(_inMemoryTasks);
  }
  // --- КОНЕЦ ЗАМЕНЫ ---

  // 2. Загрузка данных из Supabase
  Future<List<Map<String, dynamic>>> fetchTasks() async {
    final data = await Supabase.instance.client
        .from('tasks')
        .select()
        .timeout(const Duration(seconds: 15));

    _inMemoryTasks = List<Map<String, dynamic>>.from(data);
    await _tasksBox.put('all_tasks', json.encode(data));
    return _inMemoryTasks;
  }

  // 3. Подписка на сокеты (Realtime)
  void initRealtime({required Function onTasksChanged, required Function onZenChanged}) {
    _realtimeChannel = Supabase.instance.client.channel('public_changes');
    _realtimeChannel!
        .onPostgresChanges(
            event: PostgresChangeEvent.all, 
            schema: 'public', 
            table: 'tasks',
            callback: (payload) {
              // При любом внешнем изменении перечитываем сеть
              onTasksChanged();
            })
        .onPostgresChanges(
            event: PostgresChangeEvent.all, 
            schema: 'public', 
            table: 'user_status',
            callback: (payload) => onZenChanged())
        .subscribe();
  }

  void dispose() {
    _realtimeChannel?.unsubscribe();
  }
  
  // 5. Создание задачи (Мгновенный Optimistic UI + Фикс типов для календаря)
  Future<int?> addTask(Map<String, dynamic> taskData) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;

    taskData['user_id'] = user.id;

    // Генерируем временный ID
    final tempId = -DateTime.now().millisecondsSinceEpoch;
    
    // Создаем полностью валидный объект задачи со всеми дефолтными полями,
    // чтобы календарь и фильтры 7 дней не падали из-за null-полей
    final optimisticTask = {
      'id': tempId,
      'title': taskData['title'] ?? '',
      'due_date': taskData['due_date'], // Жестко сохраняем дату для календаря!
      'due_time': taskData['due_time'],
      'note': taskData['note'],
      'priority': taskData['priority'] ?? 'none',
      'tags': taskData['tags'],
      'recurrence': taskData['recurrence'],
      'is_completed': taskData['is_completed'] ?? false,
      'parent_id': taskData['parent_id'],
      'folder': taskData['folder'],
      'workspace_id': taskData['workspace_id'],
      'assigned_to': taskData['assigned_to'],
      'user_id': user.id,
    };

    // Мгновенно пушим в кэш оперативной памяти (синхронно!)
    _inMemoryTasks.add(optimisticTask);
    
    // Асинхронно сохраняем в Hive на диск (не блокируя выполнение)
    _tasksBox.put('all_tasks', json.encode(_inMemoryTasks));

    // Фоновая отправка на сервер Supabase
    try {
      final response = await Supabase.instance.client
          .from('tasks')
          .insert(taskData)
          .select()
          .single();

      final realId = response['id'] as int;
      
      // Заменяем временную задачу на официальную серверную в нашем кэше памяти
      final idx = _inMemoryTasks.indexWhere((t) => t['id'] == tempId);
      if (idx != -1) {
        _inMemoryTasks[idx] = Map<String, dynamic>.from(response);
        await _tasksBox.put('all_tasks', json.encode(_inMemoryTasks));
      }

      return realId;
    } catch (e) {
      print("Фоновое сохранение на сервер не удалось: $e");
      return tempId; 
    }
  }
  // --- КОНЕЦ ИЗМЕНЕНИЙ В СЕРВИСЕ ---
  // --- КОНЕЦ ЗАМЕНЫ ---

  // 6. Обновление задачи
  Future<void> updateTask(int taskId, Map<String, dynamic> updates) async {
    await Supabase.instance.client.from('tasks').update(updates).eq('id', taskId);
  }

  // 7. Удаление задачи
  Future<void> deleteTask(int taskId) async {
    await Supabase.instance.client.from('tasks').delete().eq('id', taskId);
  }
}

