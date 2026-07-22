import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:confetti/confetti.dart';
import 'package:file_picker/file_picker.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config.dart';
import '../core/localization.dart';
import '../services/task_service.dart';
import '../widgets/main_content_area.dart';
import '../widgets/sidebar_menu.dart';
import '../widgets/window_buttons.dart';
import '../widgets/task_cards.dart';
import '../widgets/statistics_dashboard.dart';
import '../widgets/ai_chat_panel.dart';
import '../dialogs/workspace_dialogs.dart';
import '../dialogs/team_pulse_dialog.dart';

class DesktopPlannerScreen extends StatefulWidget {
  final bool isDark;
  final VoidCallback toggleTheme;
  final String currentLang;
  final Function(String) changeLang;

  const DesktopPlannerScreen({
    super.key,
    required this.isDark,
    required this.toggleTheme,
    required this.currentLang,
    required this.changeLang,
  });

  @override
  State<DesktopPlannerScreen> createState() => _DesktopPlannerScreenState();
}

class _DesktopPlannerScreenState extends State<DesktopPlannerScreen> {
  final TextEditingController _aiChatController = TextEditingController();
  final TaskService _taskService = TaskService();
  double _s = 1.0;

  late stt.SpeechToText _speechToText;
  bool _speechEnabled = false;
  bool _isListening = false;
  String _currentLocaleId = 'ru_RU';

  // 3. КОЛЛЕКЦИЯ ДЛЯ УМНЫХ ТАЙМЕРОВ (БЕЗ НАГРУЗКИ НА CPU)
  final Map<String, Timer> _activeAlarms = {};

  List<Map<String, dynamic>> tasks = [];
  Map<String, dynamic>? _taskToDuplicate;
  bool _isDuplicating = false;

  String selectedMenu = 'Мой день';
  final String baseUrl = AppConfig.backendBaseUrl;
  bool isAiTyping = false;
  bool _isOffline = false;
  // Сводку о пропущенных дедлайнах показываем один раз за запуск приложения,
  // при первой успешной загрузке задач — не при каждом _fetchTasks().
  bool _hasCheckedMissedDeadlinesOnStartup = false;
  // Сколько изменений ждут отправки на сервер (см. TaskService.pendingOpsCount) —
  // отражается в шапке, чтобы пользователь не думал, будто изменение просто исчезло.
  int _pendingOpsCount = 0;
  String rightPanelState = 'none';
  DateTime _currentCalendarDate = DateTime.now();

  String? activeTagFilter;

  late Box _settingsBox;
  List<String> customFolders = [];

  List<Map<String, dynamic>> workspaces = [];
  // Канал для живой синхронизации задач


// --- АВАТАРКИ КОМАНДЫ ---
  // Словарь: Ключ - ID команды, Значение - список участников
  Map<int, List<Map<String, dynamic>>> workspaceMembers = {};
  // --- ФАЗА 3: ФОКУСИРОВАНИЕ (ZEN MODE) ---
  Map<String, bool> zenStatuses = {}; // Храним статусы коллег
  bool _isMyZenActive = false; // Мой личный статус

  // Скачиваем актуальные статусы из базы
  Future<void> _fetchZenStatuses() async {
    try {
      final data = await Supabase.instance.client.from('user_status').select('user_id, is_in_zen');
      if (mounted) {
        setState(() {
          zenStatuses.clear();
          for (var row in data) {
            zenStatuses[row['user_id'].toString()] = row['is_in_zen'] == true;
            // Проверяем свой собственный статус
            if (row['user_id'].toString() == Supabase.instance.client.auth.currentUser?.id) {
              _isMyZenActive = row['is_in_zen'] == true;
            }
          }
        });
      }
    } catch (e) { print("Ошибка загрузки статусов Zen: $e"); }
  }

  // Включаем/Выключаем режим
  Future<void> _toggleZenMode() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    
    final newState = !_isMyZenActive;
    
    try {
      // Отправляем в БД: если включили, ставим таймер на 45 минут
      await Supabase.instance.client.from('user_status')
          .update({
            'is_in_zen': newState, 
            'zen_until': newState ? DateTime.now().add(AppConfig.zenModeDuration).toIso8601String() : null
          })
          .eq('user_id', user.id);
          
      setState(() => _isMyZenActive = newState);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newState ? "Фокусирование включено! Уведомления заглушены" : "Фокусирование выключено!"), 
            backgroundColor: newState ? Colors.deepPurpleAccent : Colors.blueAccent
          )
        );
      }
    } catch (e) { print("Ошибка активации Zen: $e"); }
  }

  // Функция скачивает имена и профили участников из базы
  Future<void> _fetchWorkspaceMembers(int wsId) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'get_workspace_members',
        params: {'ws_id': wsId},
      );
      
      if (mounted) {
        setState(() {
          workspaceMembers[wsId] = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      print("Ошибка загрузки профилей: $e");
    }
  }

  List<Map<String, String>> chatMessages = [
    {'role': 'ai', 'text': 'Привет! Вставь текст, напиши руками или нажми на микрофон и надиктуй задачи голосом! 🔥'}
  ];
  final List<String> menuItems = ['Мой день', 'Следующие 7 дней', 'Все задачи', 'Календарь', 'Входящие', 'Статистика'];
  final List<String> weekdaysRu = ['понедельник', 'вторник', 'среда', 'четверг', 'пятница', 'суббота', 'воскресенье'];

  bool get isDark => widget.isDark;
  Color get bgColor => Colors.transparent;
  String get bgImagePath => isDark ? 'assets/images/bg_dark.jpg' : 'assets/images/bg_light.jpg';
  Color get glassColor => isDark ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.3);
  Color get glassBorderColor => isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.15);
  Color get panelColor => glassColor;
  Color get cardColor => glassColor;
  Color get doneCardColor => isDark ? Colors.black.withOpacity(0.4) : Colors.white.withOpacity(0.5);
  Color get borderColor => glassBorderColor;
  Color get borderStrong => isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.1);
  Color get textColor => isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B);
  Color get textMuted => isDark ? Colors.white70 : Colors.black54;
  Color get highlightColor => isDark ? Colors.blueAccent.withOpacity(0.3) : Colors.blueAccent.withOpacity(0.15);
  Color get chatBubbleAi => isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05);
  Color get chatInput => isDark ? Colors.black.withOpacity(0.4) : Colors.white.withOpacity(0.5);

  Widget _buildGlassContainer({required Widget child, BorderRadius? borderRadius, EdgeInsetsGeometry? padding, EdgeInsetsGeometry? margin, Color? customColor}) {
    return Container(margin: margin, child: ClipRRect(borderRadius: borderRadius ?? BorderRadius.circular(16), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 18.0, sigmaY: 18.0), child: Container(padding: padding, decoration: BoxDecoration(color: customColor ?? glassColor, borderRadius: borderRadius ?? BorderRadius.circular(16), border: Border.all(color: glassBorderColor, width: 1.0)), child: child))));
  }

  Widget _buildUserAccountBlock() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return const SizedBox.shrink();

    final metadata = user.userMetadata ?? {};
    final fullName = metadata['full_name']?.toString() ?? 'Без имени';
    final avatarUrl = metadata['avatar_url']?.toString();
    final initial = fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16 * _s),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16 * _s),
          onTap: _showAccountSettingsDialog, 
          child: Container(
            padding: EdgeInsets.all(12 * _s),
            decoration: BoxDecoration(
              color: glassColor,
              borderRadius: BorderRadius.circular(16 * _s),
              border: Border.all(color: glassBorderColor),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20 * _s, // <-- Масштабируем аватарку
                  backgroundColor: isDark ? Colors.black45 : Colors.white54,
                  backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null 
                    ? Text(initial, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18 * _s))
                    : null,
                ),
                SizedBox(width: 12 * _s),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(fullName, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14 * _s), overflow: TextOverflow.ellipsis),
                      Text("Настройки".tr(widget.currentLang), style: TextStyle(color: textMuted, fontSize: 12 * _s)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  late ConfettiController _confettiController;
  // Храним дату (ДД.ММ.ГГГГ), для которой уже показывали обзор — а не просто bool,
  // иначе поздравление не повторится на следующий день без перезапуска приложения.
  String? _dailyReviewShownForDate;

  // Даты, для которых уже показали предупреждение о перегрузке — чтобы не спамить
  // диалогом на каждой 11-й, 12-й и т.д. задаче после смены `== 10` на `>= 10`.
  final Set<String> _burnoutWarnedDates = {};

  @override
  void initState() {
    super.initState();
    _settingsBox = Hive.box('settings');
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));

    _loadLocalData(); 
    _fetchTasks();    
    _fetchWorkspaces(); 
    _fetchZenStatuses(); // <--- Добавили запуск загрузки статусов
    _initRealtime(); // <--- ВОТ ЭТА НОВАЯ СТРОЧКА
    
    _initSpeech();
    _initGlobalHotkeys();
  }

  void _loadLocalData() {
    final savedFolders = _settingsBox.get('custom_folders');
    if (savedFolders != null) {
      customFolders = List<String>.from(json.decode(savedFolders));
    }
    final cachedTasks = _taskService.getCachedTasks();
    if (cachedTasks.isNotEmpty) {
      setState(() {
        tasks = cachedTasks;
        _rebuildAllAlarms();
      });
    }
  }

  void _initGlobalHotkeys() async {
    HotKey hotKey = HotKey(key: PhysicalKeyboardKey.space, modifiers: [HotKeyModifier.control], scope: HotKeyScope.system);
    await hotKeyManager.register(hotKey, keyDownHandler: (hotKey) { appWindow.show(); appWindow.restore(); _showManualAddDialog(); });

    HotKey searchKey = HotKey(key: PhysicalKeyboardKey.keyF, modifiers: [HotKeyModifier.control], scope: HotKeyScope.inapp);
    await hotKeyManager.register(searchKey, keyDownHandler: (hotKey) => _showSearchDialog());
  }

  void _deleteFolder(String folderName) {
    setState(() {
      if (selectedMenu == folderName) selectedMenu = 'Мой день';
      customFolders.remove(folderName);
      _settingsBox.put('custom_folders', json.encode(customFolders));
    });
  }

  @override
  void dispose() {
    _taskService.dispose(); // <--- ЗАКРЫВАЕМ СОКЕТ ЧЕРЕЗ СЕРВИС
    _aiChatController.dispose();
    _confettiController.dispose();
    for (var timer in _activeAlarms.values) {
      timer.cancel();
    }
    super.dispose();
  }

// --- НОВЫЙ МЕТОД ЗАГРУЗКИ КОМАНД ---
  Future<void> _fetchWorkspaces() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      // Ищем команды, где юзер является создателем ИЛИ участником
      final memberResponse = await Supabase.instance.client
          .from('workspace_members')
          .select('workspace_id')
          .eq('user_id', user.id);

      final List<int> workspaceIds = memberResponse.map<int>((m) => m['workspace_id'] as int).toList();

      if (workspaceIds.isNotEmpty) {
        final data = await Supabase.instance.client
            .from('workspaces')
            .select()
            .inFilter('id', workspaceIds)
            .order('created_at', ascending: true);

        if (mounted) {
          setState(() {
            workspaces = List<Map<String, dynamic>>.from(data);
          });
        }
      } else {
        if (mounted) setState(() => workspaces = []);
      }
    } catch (e) {
      print("Ошибка загрузки команд: $e");
    }
  }

   void _checkDailyReviewTrigger() {
    final todayStr = _formatDate(DateTime.now());
    if (_dailyReviewShownForDate == todayStr) return; // Уже хвалили сегодня — пропускаем

    final todayTasks = tasks.where((t) => t['due_date'] == todayStr && t['parent_id'] == null).toList();

    // Если на сегодня вообще не было задач — ничего не делаем
    if (todayTasks.isEmpty) return;

    // Проверяем, все ли задачи на сегодня выполнены
    final allDone = todayTasks.every((t) => t['is_completed'] == true);

    if (allDone) {
      _dailyReviewShownForDate = todayStr;
      _showDailyReviewOverlay(todayTasks.length);
    }
  }
  // 4. ЛОГИКА УМНЫХ БУДИЛЬНИКОВ
  void _rebuildAllAlarms() {
    for (var timer in _activeAlarms.values) {
      timer.cancel();
    }
    _activeAlarms.clear();

    for (var task in tasks) {
      _scheduleTaskAlarms(task);
    }
  }

  void _scheduleTaskAlarms(Map<String, dynamic> task) {
    if (task['is_completed'] == true || task['due_date'] == null || task['due_time'] == null) return;
    final int taskId = task['id'];

    final taskDate = _parseDate(task['due_date']);
    if (taskDate == null) return;
    final timeParts = task['due_time'].toString().split(':');
    if (timeParts.length != 2) return;

    final taskTime = DateTime(taskDate.year, taskDate.month, taskDate.day, int.parse(timeParts[0]), int.parse(timeParts[1]));
    final now = DateTime.now();

    void setTimer(DateTime alarmTime, int offset, String title, String body) {
      if (alarmTime.isAfter(now)) {
        final delay = alarmTime.difference(now);
        final alarmId = '${taskId}_$offset';
        _activeAlarms[alarmId] = Timer(delay, () {
          _triggerPushNotification(title, body);
          _activeAlarms.remove(alarmId);
        });
      }
    }

    // Ровно 3 невидимых "будильника" + 1 в момент дедлайна
    setTimer(taskTime.subtract(const Duration(days: 3)), 1, "Бро, скоро дедлайн!", "Задача '${task['title']}' через 3 дня.");
    setTimer(taskTime.subtract(const Duration(days: 1)), 2, "Завтра сдавать!", "Задача '${task['title']}' завтра в ${task['due_time']}.");
    setTimer(taskTime.subtract(const Duration(hours: 1)), 3, "Время пришло!", "Задача '${task['title']}' через 1 час.");
    setTimer(taskTime, 4, "Дедлайн!", "Задача '${task['title']}' прямо сейчас!");
  }

  Future<void> _triggerPushNotification(String title, String body) async {
    // 🚀 ЕСЛИ МЫ В ФОКУСЕ - БЛОКИРУЕМ ЛЮБЫЕ ПУШИ ОТ ЗАДАЧ
    if (_isMyZenActive) return; 

    try {
      LocalNotification notification = LocalNotification(
        title: title,
        body: body,
      );
      
      // Магия: если юзер кликнет по пушу в Windows, приложение развернется из трея!
      notification.onClick = () {
        appWindow.show();
        appWindow.restore();
      };

      await notification.show();
    } catch (e) {
      print("Ошибка отправки пуша: $e");
      // Если пуш не сработал, показываем внутриигровой снекбар
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.blueAccent, 
            content: Text("$title: $body", style: const TextStyle(color: Colors.white))
          )
        );
      }
    }
  }

  void _initSpeech() async {
    _speechToText = stt.SpeechToText();
    try {
      _speechEnabled = await _speechToText.initialize(onStatus: (status) { if (status == 'done' || status == 'notListening') { if (mounted) setState(() => _isListening = false); } }, onError: (err) { if (mounted) setState(() => _isListening = false); });
      if (_speechEnabled) {
        var systemLocales = await _speechToText.locales();
        var ruLocale = systemLocales.firstWhere((locale) => locale.localeId.toLowerCase().contains('ru'), orElse: () => systemLocales.first);
        _currentLocaleId = ruLocale.localeId;
      }
      if (mounted) setState(() {});
    } catch (e) { print("Ошибка микрофона: $e".tr(widget.currentLang)); }
  }

  void _toggleListening() async {
    if (!_speechEnabled) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Микрофон недоступен."), backgroundColor: Colors.redAccent)); return; }
    if (_speechToText.isListening) { await _speechToText.stop(); setState(() => _isListening = false); } 
    else { setState(() => _isListening = true); final currentText = _aiChatController.text; await _speechToText.listen(localeId: _currentLocaleId, onResult: (result) { setState(() { if (currentText.isEmpty) { _aiChatController.text = result.recognizedWords; } else { _aiChatController.text = "$currentText ${result.recognizedWords}"; } }); }); }
  }

  String _formatDate(DateTime d) => "${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}";
  DateTime? _parseDate(String dateStr) { try { final parts = dateStr.split('.'); if (parts.length == 3) return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0])); } catch (e) { return null; } return null; }

  Color _getPriorityColor(String? priority) { switch (priority) { case 'red': return Colors.redAccent; case 'orange': return Colors.orangeAccent; case 'blue': return Colors.lightBlue; case 'gray': return textMuted; default: return borderStrong; } }

  List<Map<String, dynamic>> get filteredTasks { if (activeTagFilter == null) return tasks; return tasks.where((t) { if (t['tags'] == null) return false; List<String> tTags = t['tags'].toString().split(',').map((e) => e.trim()).toList(); return tTags.contains(activeTagFilter); }).toList(); }
  Map<String, int> _getSubtaskStats(dynamic parentId) { final subtasks = tasks.where((t) => t['parent_id'] == parentId).toList(); if (subtasks.isEmpty) return {'total': 0, 'done': 0}; return {'total': subtasks.length, 'done': subtasks.where((t) => t['is_completed'] == true).length}; }

  Future<void> _fetchTasks() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final fetchedTasks = await _taskService.fetchTasks();
      if (mounted) {
        setState(() {
          tasks = fetchedTasks;
          _isOffline = false;
          _pendingOpsCount = _taskService.pendingOpsCount;
          _applyFilters();
          _rebuildAllAlarms();
        });
        _checkMissedDeadlinesOnStartup();
      }
    } catch (e) {
      print("!!! РЕАЛЬНАЯ ОШИБКА БАЗЫ ДАННЫХ: $e");
      if (mounted) {
        setState(() {
          _isOffline = true;
          _pendingOpsCount = _taskService.pendingOpsCount;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.wifi_off, color: Colors.white),
                const SizedBox(width: 12),
                Text("Нет сети. Работаем локально!".tr(widget.currentLang)),
              ],
            ),
            backgroundColor: Colors.orangeAccent,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(20),
          ),
        );
      }
    }
  }

  // Уведомления о дедлайнах (см. _scheduleTaskAlarms) работают только пока
  // приложение запущено — это Dart Timer, не системный планировщик ОС.
  // Настоящие OS-level scheduled-уведомления через flutter_local_notifications
  // технически возможны на Windows (zonedSchedule), но их cancel() официально
  // не работает для приложений, не упакованных в MSIX (см. README пакета
  // flutter_local_notifications_windows) — а Clarify сейчас распространяется
  // как обычный .exe. Использовать их означало бы получить уведомления,
  // которые нельзя отменить при переносе/выполнении/удалении задачи — то есть
  // риск показать уведомление с устаревшим содержимым, что хуже отсутствия
  // уведомления вовсе. Поэтому вместо этого — сводка при следующем запуске:
  // честный, проверяемый компромисс, не требующий MSIX-упаковки.
  void _checkMissedDeadlinesOnStartup() {
    if (_hasCheckedMissedDeadlinesOnStartup) return;
    _hasCheckedMissedDeadlinesOnStartup = true;

    final overdueTasks = tasks.where((t) => _isOverdue(t)).toList();
    if (overdueTasks.isEmpty) return;

    final firstTitle = overdueTasks.first['title'] ?? '';
    final body = overdueTasks.length == 1
        ? 'Задача "$firstTitle" просрочена.'
        : 'Просрочено задач: ${overdueTasks.length}. Например: "$firstTitle".';

    _triggerPushNotification('Пока вас не было', body);
  }

  // --- МАГИЯ REALTIME ---
  void _initRealtime() {
    _taskService.initRealtime(
      onTasksChanged: () => _fetchTasks(),
      onZenChanged: () => _fetchZenStatuses(),
    );
  }

  Future<void> _sendTaskToAI(String text) async {
    if (text.trim().isEmpty) return;
    setState(() { chatMessages.add({'role': 'user', 'text': text.trim()}); isAiTyping = true; }); _aiChatController.clear();
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final response = await http.post(
        Uri.parse('$baseUrl/tasks/parse'), 
        headers: {'Content-Type': 'application/json'}, 
        body: json.encode({
          'text': text,
          'user_id': user?.id 
        })
      );
      
      if (response.statusCode == 200) { 
        final List addedTasks = json.decode(response.body); 
        await _fetchTasks(); 
        setState(() { chatMessages.add({'role': 'ai', 'text': 'Готово! Добавлено задач: ${addedTasks.length}. '.tr(widget.currentLang)}); isAiTyping = false; }); 
      } 
      else { setState(() { chatMessages.add({'role': 'ai', 'text': 'Ошибка: сервер вернул ${response.statusCode}'}); isAiTyping = false; }); }
    } catch (e) { setState(() { chatMessages.add({'role': 'ai', 'text': 'Ошибка связи с ИИ.'.tr(widget.currentLang)}); isAiTyping = false; }); }
  }

  // Вставь этот блок вместо старой функции _createTaskManually

  // --- ЗАМЕНИ ФУНКЦИЮ _createTaskManually ПОЛНОСТЬЮ НА ЭТОТ КУСОК ---
  Future<int?> _createTaskManually(Map<String, dynamic> taskData) async {
    try {
      final taskFuture = _taskService.addTask(taskData); 
      
      // СИНХРОННОЕ ОБНОВЛЕНИЕ ЭКРАНА
      setState(() {
        // Оборачиваем в List.from для 100% гарантии смены ссылки
        tasks = List<Map<String, dynamic>>.from(_taskService.getCachedTasks()); 
        
        // Вызов _applyFilters() можешь смело удалить, раз он пустой!
      });
      
      final newTaskId = await taskFuture;
      await _fetchTasks(); 
      return newTaskId;
    } catch (e) {
      print("Ошибка создания задачи: $e".tr(widget.currentLang));
      return null;
    }
  }
// --- КОНЕЦ ЗАМЕНЫ ---

// Ниже идет следующий метод твоего класса...

  Future<void> _updateTaskData(dynamic taskId, Map<String, dynamic> taskData) async {
    try {
      await _taskService.updateTask(taskId, taskData); // <--- ИСПОЛЬЗУЕМ СЕРВИС

      await _fetchTasks();
    } catch (e) {
      // updateTask уже поставил изменение в очередь на повтор (TaskService.flushPendingOps) —
      // сообщаем об этом пользователю, а не просто теряем изменение молча.
      print("Ошибка обновления задачи: $e".tr(widget.currentLang));
      if (mounted) {
        setState(() => _pendingOpsCount = _taskService.pendingOpsCount);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Нет сети. Изменение отправим, когда сеть восстановится.".tr(widget.currentLang)),
            backgroundColor: Colors.orangeAccent,
          ),
        );
      }
    }
  }

  Future<void> _spawnNextRecurringTask(Map<String, dynamic> task) async {
    DateTime? oldDate = _parseDate(task['due_date']); if (oldDate == null) return;
    DateTime newDate = oldDate; if (task['recurrence'] == 'daily') newDate = oldDate.add(const Duration(days: 1)); else if (task['recurrence'] == 'weekly') newDate = oldDate.add(const Duration(days: 7)); else if (task['recurrence'] == 'monthly') newDate = DateTime(oldDate.year, oldDate.month + 1, oldDate.day);
    int? newTaskId = await _createTaskManually({"title": task['title'], "due_date": _formatDate(newDate), "due_time": task['due_time'], "note": task['note'], "priority": task['priority'], "tags": task['tags'], "recurrence": task['recurrence'], "parent_id": task['parent_id'], "is_completed": false});
    if (newTaskId != null && task['parent_id'] == null) { final subtasks = tasks.where((t) => t['parent_id'] == task['id']).toList(); for (var sub in subtasks) { await _createTaskManually({"title": sub['title'], "parent_id": newTaskId, "is_completed": false}); } }
  }

  Future<void> _toggleTask(Map<String, dynamic> task) async {
    final bool currentStatus = task['is_completed'] == true;
    final bool newStatus = !currentStatus;

    setState(() {
      task['is_completed'] = newStatus;
      _applyFilters();
    });

    try {
      await _taskService.updateTask(task['id'], {'is_completed': newStatus}); // <--- ИСПОЛЬЗУЕМ СЕРВИС

      if (newStatus == true && task['recurrence'] != null && task['recurrence'] != 'none') {
        _spawnNextRecurringTask(task);
      }
      
      _fetchTasks(); 
      
      // ВОТ СЮДА ДОБАВЛЯЕМ ПРОВЕРКУ
      if (newStatus == true) {
        _checkDailyReviewTrigger();
      }
      
    } catch (e) {
      setState(() {
        task['is_completed'] = currentStatus;
        _applyFilters();
      });
      print("Ошибка обновления статуса: $e");
    }
  }

void _showDailyReviewOverlay(int taskCount) {
    _confettiController.play();
    
    showGeneralDialog(
      context: context,
      barrierDismissible: false, // Запрещаем закрывать кликом мимо (юзер должен насладиться)
      barrierLabel: 'DailyReview',
      transitionDuration: const Duration(milliseconds: 600),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Stack(
          children: [
            // 1. Тотальное размытие всего приложения (тот самый "Фокус")
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
              child: Container(color: Colors.black.withOpacity(0.5)),
            ),
            
            // 2. Карточка с поздравлением
            Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 450 * _s,
                  padding: EdgeInsets.all(40 * _s),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E).withOpacity(0.8) : Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(32 * _s),
                    border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
                    boxShadow: [
                      BoxShadow(color: Colors.blueAccent.withOpacity(0.2), blurRadius: 40, spreadRadius: 10)
                    ]
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("🎉", style: TextStyle(fontSize: 70 * _s)),
                      SizedBox(height: 24 * _s),
                      Text("Отличная работа!", style: TextStyle(color: textColor, fontSize: 32 * _s, fontWeight: FontWeight.w900)),
                      SizedBox(height: 16 * _s),
                      Text(
                        "Ты закрыл все задачи на сегодня ($taskCount шт).\nСистема синхронизирована. Можешь со спокойной душой закрывать приложение.\nОтдыхай, ты это заслужил!", 
                        textAlign: TextAlign.center, 
                        style: TextStyle(color: textMuted, fontSize: 16 * _s, height: 1.5)
                      ),
                      SizedBox(height: 40 * _s),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 40 * _s, vertical: 20 * _s),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16 * _s)),
                          elevation: 0,
                        ),
                        onPressed: () {
                          _confettiController.stop();
                          Navigator.pop(context);
                        },
                        child: Text("Завершить день", style: TextStyle(fontSize: 18 * _s, fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                ),
              ),
            ),
            
            // 3. Праздничный взрыв конфетти во все стороны
            Align(
              alignment: Alignment.center,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive, // <-- ВЗРЫВ ВО ВСЕ СТОРОНЫ
                emissionFrequency: 0.05,
                numberOfParticles: 50, // Увеличили количество частичек для красоты
                maxBlastForce: 100,
                minBlastForce: 80,
                gravity: 0.1, // Сделали падение чуть более плавным (затяжным)
                colors: const [Colors.blueAccent, Colors.greenAccent, Colors.white, Colors.orangeAccent, Colors.purpleAccent],
              ),
            ),
          ],
        );
      },
    );
  }

void _checkBurnoutWarning(String dateStr) {
    if (_burnoutWarnedDates.contains(dateStr)) return; // Уже предупреждали про этот день

    final dayTasks = tasks.where((t) => t['due_date'] == dateStr && t['parent_id'] == null).toList();

    if (dayTasks.length >= AppConfig.burnoutTaskThreshold) {
      _burnoutWarnedDates.add(dateStr);
      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'BurnoutWarning',
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) {
          return Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 380 * _s,
                padding: EdgeInsets.all(32 * _s),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E).withOpacity(0.95) : Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(24 * _s),
                  border: Border.all(color: Colors.blueAccent.withOpacity(0.3), width: 2),
                  boxShadow: [
                    BoxShadow(color: Colors.blueAccent.withOpacity(0.1), blurRadius: 20, spreadRadius: 5)
                  ]
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.self_improvement, size: 60 * _s, color: Colors.blueAccent),
                    SizedBox(height: 20 * _s),
                    Text("Эй, притормози! 🛑", style: TextStyle(color: textColor, fontSize: 24 * _s, fontWeight: FontWeight.w900)),
                    SizedBox(height: 12 * _s),
                    Text(
                      "Это уже 10-я задача на этот день.\n\nПродуктивность — это прекрасно, но выгорание нам ни к чему. Постарайся не перегружать расписание и обязательно оставляй окна для отдыха.\nТы не робот! 🤖", // <-- Текст тоже обновили
                      textAlign: TextAlign.center, 
                      style: TextStyle(color: textMuted, fontSize: 14 * _s, height: 1.5)
                    ),
                    SizedBox(height: 28 * _s),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 32 * _s, vertical: 16 * _s),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12 * _s)),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text("Понял, спасибо", style: TextStyle(fontSize: 15 * _s, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              ),
            ),
          );
        },
      );
    }
  }

  Future<void> _deleteTask(dynamic taskId) async {
    // Удаляем локально сразу (как и при создании задачи) — теперь это безопасно:
    // если сеть недоступна, TaskService поставит удаление в очередь и повторит
    // его сам при следующей успешной синхронизации.
    setState(() {
      tasks.removeWhere((t) => t['id'] == taskId);
      _applyFilters();
      _rebuildAllAlarms();
    });

    try {
      await _taskService.deleteTask(taskId); // <--- ИСПОЛЬЗУЕМ СЕРВИС
    } catch (e) {
      print("Ошибка удаления: $e".tr(widget.currentLang));
      if (mounted) {
        setState(() => _pendingOpsCount = _taskService.pendingOpsCount);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Нет сети. Удаление отправим, когда сеть восстановится.".tr(widget.currentLang)),
            backgroundColor: Colors.orangeAccent,
          ),
        );
      }
    }
  }
  
  void _applyFilters() {}

  void shiftDate(int days, int months, StateSetter setStateDialog, DateTime? currentDate) { DateTime baseDate = currentDate ?? DateTime.now(); setStateDialog(() => currentDate = DateTime(baseDate.year, baseDate.month + months, baseDate.day + days)); }

  void _showSearchDialog() {
    String query = '';
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          final searchResults = query.isEmpty ? [] : tasks.where((t) => 
            (t['title']?.toString().toLowerCase().contains(query.toLowerCase()) ?? false) ||
            (t['note']?.toString().toLowerCase().contains(query.toLowerCase()) ?? false)
          ).toList();

          return Center(
            child: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: 600,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildGlassContainer(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: TextField(
                        autofocus: true,
                        style: TextStyle(color: textColor, fontSize: 20),
                        decoration: InputDecoration(
                          hintText: "Поиск задач...".tr(widget.currentLang),
                          hintStyle: TextStyle(color: textMuted),
                          border: InputBorder.none,
                          icon: const Icon(Icons.search, color: Colors.blueAccent, size: 28),
                        ),
                        onChanged: (val) => setStateDialog(() => query = val),
                      ),
                    ),
                    if (query.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildGlassContainer(
                        padding: const EdgeInsets.all(12),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 400),
                          child: searchResults.isEmpty 
                            ? Padding(padding: const EdgeInsets.all(16), child: Text("Ничего не найдено".tr(widget.currentLang), style: TextStyle(color: textMuted)))
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: searchResults.length,
                                itemBuilder: (context, index) {
                                  final task = searchResults[index];
                                  return ListTile(
                                    title: Text(task['title'] ?? '', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                                    subtitle: task['note'] != null ? Text(task['note'], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: textMuted)) : null,
                                    trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.blueAccent),
                                    onTap: () {
                                      Navigator.pop(context);
                                      _showTaskDetailsDialog(task); 
                                    },
                                  );
                                },
                              ),
                        )
                      )
                    ]
                  ],
                ),
              ),
            ),
          );
        });
      }
    );
  }

  void _showManualAddDialog({DateTime? preselectedDate, Map<String, dynamic>? sourceTaskForDuplicate}) {
    final bool isFromDuplicate = sourceTaskForDuplicate != null;
    final TextEditingController titleController = TextEditingController(text: isFromDuplicate ? sourceTaskForDuplicate['title'] : '');
    final TextEditingController noteController = TextEditingController(text: isFromDuplicate ? (sourceTaskForDuplicate['note'] ?? '') : '');
    final TextEditingController tagsController = TextEditingController(text: isFromDuplicate ? (sourceTaskForDuplicate['tags'] ?? '') : (activeTagFilter ?? ''));
    final TextEditingController subtaskController = TextEditingController();

    String selectedPriority = isFromDuplicate ? (sourceTaskForDuplicate['priority'] ?? 'none') : 'none';
    String selectedRecurrence = isFromDuplicate ? (sourceTaskForDuplicate['recurrence'] ?? 'none') : 'none';
    String? selectedAssigneeId;
    DateTime? selectedDate = preselectedDate ?? DateTime.now(); TimeOfDay? selectedTime;

    if (isFromDuplicate && sourceTaskForDuplicate['due_time'] != null) {
      final parts = sourceTaskForDuplicate['due_time'].split(':');
      selectedTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }

    List<String> tempSubtasks = [];
    if (isFromDuplicate) {
      final existingSubs = tasks.where((t) => t['parent_id'] == sourceTaskForDuplicate['id']).toList();
      tempSubtasks = existingSubs.map((s) => s['title'].toString()).toList();
    }

    

    bool isSaving = false;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return Center(
            child: Material(
              color: Colors.transparent, 
              child: _buildGlassContainer(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: 450,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(isFromDuplicate ? "Дублирование".tr(widget.currentLang) : "Новая задача".tr(widget.currentLang), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: textColor)),
                            IconButton(icon: Icon(Icons.close, color: textMuted), onPressed: () { Navigator.pop(context); if (_isDuplicating) setState(() { _isDuplicating = false; _taskToDuplicate = null; }); })
                          ]
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: titleController,
                          style: TextStyle(color: textColor, fontSize: 16),
                          autofocus: true,
                          onChanged: (value) {
                            final parsed = _parseSmartInput(value);
                            if (parsed['time'] != null) {
                              final parts = parsed['time'].split(':');
                              setStateDialog(() => selectedTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])));
                            }
                            if (parsed['tags'] != null) {
                              final currentTags = tagsController.text.trim();
                              if (!currentTags.contains(parsed['tags'])) {
                                tagsController.text = currentTags.isEmpty ? parsed['tags'] : "$currentTags, ${parsed['tags']}";
                              }
                            }
                          },
                          decoration: InputDecoration(labelText: "Заголовок".tr(widget.currentLang), labelStyle: TextStyle(color: textMuted), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: glassBorderColor)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: glassBorderColor)))
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text("Приоритет: ".tr(widget.currentLang), style: TextStyle(color: textMuted, fontSize: 14)),
                            const SizedBox(width: 8),
                            ...['none', 'red', 'orange', 'blue', 'gray'].map((pVal) {
                              Color btnColor = pVal == 'none' ? Colors.transparent : _getPriorityColor(pVal);
                              bool isSelected = selectedPriority == pVal;
                              return GestureDetector(
                                onTap: () => setStateDialog(() => selectedPriority = pVal),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 8), width: 26, height: 26,
                                  decoration: BoxDecoration(color: btnColor, shape: BoxShape.circle, border: isSelected ? Border.all(color: textColor, width: 2) : Border.all(color: glassBorderColor, width: 1)),
                                  child: isSelected && pVal == 'none' ? Icon(Icons.close, size: 14, color: textMuted) : null,
                                ),
                              );
                            }),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: OutlinedButton.icon(icon: Icon(Icons.calendar_today, size: 18, color: textColor), label: Text(selectedDate == null ? "Без даты".tr(widget.currentLang) : _formatDate(selectedDate!), style: TextStyle(color: textColor)), style: OutlinedButton.styleFrom(side: BorderSide(color: glassBorderColor), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: () async { final picked = await showDatePicker(context: context, initialDate: selectedDate ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2101)); if (picked != null) setStateDialog(() => selectedDate = picked); })),
                            const SizedBox(width: 12),
                            Expanded(child: OutlinedButton.icon(icon: Icon(Icons.access_time, size: 18, color: textColor), label: Text(selectedTime == null ? "Время".tr(widget.currentLang) : selectedTime!.format(context), style: TextStyle(color: textColor)), style: OutlinedButton.styleFrom(side: BorderSide(color: glassBorderColor), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: () async { final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now()); if (picked != null) setStateDialog(() => selectedTime = picked); })),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(onPressed: () => shiftDate(1, 0, setStateDialog, selectedDate), child: Text("+1 День".tr(widget.currentLang))),
                            TextButton(onPressed: () => shiftDate(7, 0, setStateDialog, selectedDate), child: Text("+1 Неделя".tr(widget.currentLang))),
                            TextButton(onPressed: () => setStateDialog(() => selectedDate = null), child: Text("Убрать".tr(widget.currentLang), style: TextStyle(color: Colors.redAccent))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.repeat, size: 18, color: textMuted),
                            const SizedBox(width: 8),
                            DropdownButton<String>(
                              value: selectedRecurrence, dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white, underline: const SizedBox(), style: TextStyle(fontSize: 14, color: textColor),
                              items: [
                                DropdownMenuItem(value: 'none', child: Text("Без повтора".tr(widget.currentLang), style: TextStyle(color: textColor))),
                                DropdownMenuItem(value: 'daily', child: Text("Каждый день".tr(widget.currentLang), style: TextStyle(color: textColor))),
                                DropdownMenuItem(value: 'weekly', child: Text("Каждую неделю".tr(widget.currentLang), style: TextStyle(color: textColor))),
                                DropdownMenuItem(value: 'monthly', child: Text("Каждый месяц".tr(widget.currentLang), style: TextStyle(color: textColor))),
                              ],
                              onChanged: (val) => setStateDialog(() => selectedRecurrence = val!),
                            )
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(controller: tagsController, style: TextStyle(color: textColor), decoration: InputDecoration(labelText: "Теги (через запятую)".tr(widget.currentLang), labelStyle: TextStyle(color: textMuted), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: glassBorderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.blueAccent)), isDense: true)),
                        const SizedBox(height: 12),
                        TextField(controller: noteController, style: TextStyle(color: textColor), maxLines: 2, decoration: InputDecoration(labelText: "Заметка".tr(widget.currentLang), labelStyle: TextStyle(color: textMuted), alignLabelWithHint: true, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: glassBorderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.blueAccent)))),
                        const SizedBox(height: 16),
                        Divider(color: glassBorderColor),
                        const SizedBox(height: 8),
                        Text("Чек-лист (Подзадачи):".tr(widget.currentLang), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                        const SizedBox(height: 8),
                        if (tempSubtasks.isNotEmpty)
                          Column(
                            children: tempSubtasks.asMap().entries.map((entry) {
                              int idx = entry.key; String subTitle = entry.value;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: doneCardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: glassBorderColor)),
                                child: Row(
                                  children: [
                                    Icon(Icons.circle_outlined, size: 16, color: textMuted), const SizedBox(width: 8),
                                    Expanded(child: Text(subTitle, style: TextStyle(color: textColor))),
                                    IconButton(icon: Icon(Icons.close, size: 16, color: Colors.red[300]), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => setStateDialog(() => tempSubtasks.removeAt(idx)))
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: TextField(controller: subtaskController, style: TextStyle(color: textColor), decoration: InputDecoration(hintText: "Добавить пункт...".tr(widget.currentLang), hintStyle: TextStyle(color: textMuted), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: glassBorderColor)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: glassBorderColor)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), isDense: true), onSubmitted: (text) { if (text.trim().isNotEmpty) { setStateDialog(() { tempSubtasks.add(text.trim()); subtaskController.clear(); }); } })),
                            const SizedBox(width: 12),
                            IconButton(style: IconButton.styleFrom(backgroundColor: highlightColor, padding: const EdgeInsets.all(12)), icon: const Icon(Icons.add, color: Colors.blueAccent), onPressed: () { if (subtaskController.text.trim().isNotEmpty) { setStateDialog(() { tempSubtasks.add(subtaskController.text.trim()); subtaskController.clear(); }); } })
                          ],
                        ),
                        
                        // 🚀 ВЫБОР ИСПОЛНИТЕЛЯ ТЕПЕРЬ ПРАВИЛЬНО ВНУТРИ СПИСКА CHILDREN
                        if (selectedMenu.startsWith('ws_')) ...[
                          SizedBox(height: 12 * _s),
                          DropdownButtonFormField<String>(
                            dropdownColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                            decoration: InputDecoration(
                              labelText: "Назначить на...".tr(widget.currentLang),
                              labelStyle: TextStyle(color: textMuted),
                              prefixIcon: Icon(Icons.person_outline, color: textMuted, size: 20 * _s),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: glassBorderColor)),
                            ),
                            value: selectedAssigneeId,
                            items: [
                              DropdownMenuItem(value: null, child: Text("Никто", style: TextStyle(color: textColor))),
                              ...(workspaceMembers[int.parse(selectedMenu.substring(3))] ?? []).map((m) => DropdownMenuItem(
                                value: m['user_id'] as String,
                                child: Text(m['full_name'] ?? 'Участник', style: TextStyle(color: textColor)),
                              )).toList(),
                            ],
                            onChanged: (val) => setStateDialog(() => selectedAssigneeId = val),
                          ),
                        ],
                        
                        const SizedBox(height: 24),
                        
                        // КНОПКИ ОТМЕНА И СОХРАНИТЬ
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(onPressed: () { Navigator.pop(context); if (_isDuplicating) setState(() { _isDuplicating = false; _taskToDuplicate = null; }); }, child: Text("Отмена".tr(widget.currentLang), style: TextStyle(color: textMuted))),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                              onPressed: isSaving ? null : () async {
                                if (titleController.text.trim().isEmpty) return;
                                
                                setStateDialog(() => isSaving = true); 

                                int? currentWorkspaceId;
                                if (selectedMenu.startsWith('ws_')) {
                                  currentWorkspaceId = int.tryParse(selectedMenu.substring(3));
                                }

                                // --- ЗАМЕНИ ЭТОТ БЛОК ---
// Запускаем фоновую анонимную функцию для создания главной задачи и ее подзадач
() async {
  int? newTaskId = await _createTaskManually({
    "title": titleController.text.trim(),
    "due_date": selectedDate != null ? _formatDate(selectedDate!) : null,
    "due_time": selectedTime != null ? "${selectedTime!.hour.toString().padLeft(2,'0')}:${selectedTime!.minute.toString().padLeft(2,'0')}" : null,
    "note": noteController.text.trim().isNotEmpty ? noteController.text.trim() : null,
    "priority": selectedPriority,
    "tags": tagsController.text.trim().isNotEmpty ? tagsController.text.trim() : null,
    "recurrence": selectedRecurrence == 'none' ? null : selectedRecurrence,
    "is_completed": false,
    "parent_id": null,
    "folder": customFolders.contains(selectedMenu) ? selectedMenu : null,
    "workspace_id": currentWorkspaceId, 
    "assigned_to": selectedAssigneeId,
  });

  if (newTaskId != null && tempSubtasks.isNotEmpty) {
    for (String subTitle in tempSubtasks) {
      await _createTaskManually({"title": subTitle, "parent_id": newTaskId, "is_completed": false});
    }
  }
}(); // <--- Круглые скобки в конце сразу запускают эту фоновую задачу
// --- КОНЕЦ ЗАМЕНЫ ---
                                
                                if (context.mounted) Navigator.pop(context);
                                
                                if (selectedDate != null) {
                                  _checkBurnoutWarning(_formatDate(selectedDate!));
                                }
                                
                                if (_isDuplicating) {
                                  setState(() { _isDuplicating = false; _taskToDuplicate = null; });
                                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Задача скопирована!".tr(widget.currentLang)), backgroundColor: Colors.blueAccent));
                                }
                                
                                if (context.mounted) setStateDialog(() => isSaving = false);
                              },
                              child: isSaving 
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Text("Сохранить".tr(widget.currentLang), style: TextStyle(fontWeight: FontWeight.bold))
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                )
              ),
            ),
          );
        });
      },
    );
  }

  void _showEditTaskDialog(Map<String, dynamic> task) {
    final TextEditingController titleController = TextEditingController(text: task['title']);
    final TextEditingController noteController = TextEditingController(text: task['note'] ?? '');
    final TextEditingController tagsController = TextEditingController(text: task['tags'] ?? '');
    String selectedPriority = task['priority'] ?? 'none'; 
    String selectedRecurrence = task['recurrence'] ?? 'none';
    String? selectedAssigneeId = task['assigned_to']; // <-- ДОБАВИЛИ ЭТУ СТРОЧКУ
    DateTime? selectedDate = task['due_date'] != null ? _parseDate(task['due_date']) : null; TimeOfDay? selectedTime;
    if (task['due_time'] != null && task['due_time'].toString().contains(':')) { final parts = task['due_time'].split(':'); selectedTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])); }
    void localShiftDate(int days, int months, StateSetter setStateDialog) { DateTime baseDate = selectedDate ?? DateTime.now(); setStateDialog(() => selectedDate = DateTime(baseDate.year, baseDate.month + months, baseDate.day + days)); }

    bool isSaving = false;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return Center(
            child: Material(
              color: Colors.transparent,
              child: _buildGlassContainer(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: 450,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Редактировать".tr(widget.currentLang), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: textColor)),
                            IconButton(icon: Icon(Icons.close, color: textMuted), onPressed: () => Navigator.pop(context))
                          ]
                        ),
                        const SizedBox(height: 16),
                        TextField(controller: titleController, style: TextStyle(color: textColor, fontSize: 16), decoration: InputDecoration(labelText: "Заголовок".tr(widget.currentLang), labelStyle: TextStyle(color: textMuted), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: glassBorderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.blueAccent)))),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text("Приоритет: ".tr(widget.currentLang), style: TextStyle(color: textMuted, fontSize: 14)),
                            const SizedBox(width: 8),
                            ...['none', 'red', 'orange', 'blue', 'gray'].map((pVal) {
                              Color btnColor = pVal == 'none' ? Colors.transparent : _getPriorityColor(pVal);
                              bool isSelected = selectedPriority == pVal;
                              return GestureDetector(
                                onTap: () => setStateDialog(() => selectedPriority = pVal),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 8), width: 26, height: 26,
                                  decoration: BoxDecoration(color: btnColor, shape: BoxShape.circle, border: isSelected ? Border.all(color: textColor, width: 2) : Border.all(color: glassBorderColor, width: 1)),
                                  child: isSelected && pVal == 'none' ? Icon(Icons.close, size: 14, color: textMuted) : null,
                                ),
                              );
                            }),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: OutlinedButton.icon(icon: Icon(Icons.calendar_today, size: 18, color: textColor), label: Text(selectedDate == null ? "Без даты".tr(widget.currentLang) : _formatDate(selectedDate!), style: TextStyle(color: textColor)), style: OutlinedButton.styleFrom(side: BorderSide(color: glassBorderColor), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: () async { final picked = await showDatePicker(context: context, initialDate: selectedDate ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2101)); if (picked != null) setStateDialog(() => selectedDate = picked); })),
                            const SizedBox(width: 12),
                            Expanded(child: OutlinedButton.icon(icon: Icon(Icons.access_time, size: 18, color: textColor), label: Text(selectedTime == null ? "Время".tr(widget.currentLang) : selectedTime!.format(context), style: TextStyle(color: textColor)), style: OutlinedButton.styleFrom(side: BorderSide(color: glassBorderColor), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: () async { final picked = await showTimePicker(context: context, initialTime: selectedTime ?? TimeOfDay.now()); if (picked != null) setStateDialog(() => selectedTime = picked); })),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(onPressed: () => localShiftDate(1, 0, setStateDialog), child: Text("+1 День".tr(widget.currentLang))),
                            TextButton(onPressed: () => localShiftDate(7, 0, setStateDialog), child: Text("+1 Неделя".tr(widget.currentLang))),
                            TextButton(onPressed: () => setStateDialog(() => selectedDate = null), child: Text("Убрать".tr(widget.currentLang), style: TextStyle(color: Colors.redAccent))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.repeat, size: 18, color: textMuted),
                            const SizedBox(width: 8),
                            DropdownButton<String>(
                              value: selectedRecurrence, dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white, underline: const SizedBox(), style: TextStyle(fontSize: 14, color: textColor),
                              items: [
                                DropdownMenuItem(value: 'none', child: Text("Без повтора".tr(widget.currentLang), style: TextStyle(color: textColor))),
                                DropdownMenuItem(value: 'daily', child: Text("Каждый день".tr(widget.currentLang), style: TextStyle(color: textColor))),
                                DropdownMenuItem(value: 'weekly', child: Text("Каждую неделю".tr(widget.currentLang), style: TextStyle(color: textColor))),
                                DropdownMenuItem(value: 'monthly', child: Text("Каждый месяц".tr(widget.currentLang), style: TextStyle(color: textColor))),
                              ],
                              onChanged: (val) => setStateDialog(() => selectedRecurrence = val!),
                            )
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(controller: tagsController, style: TextStyle(color: textColor), decoration: InputDecoration(labelText: "Теги".tr(widget.currentLang), labelStyle: TextStyle(color: textMuted), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: glassBorderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.blueAccent)), isDense: true)),
                        const SizedBox(height: 12),
                        TextField(controller: noteController, style: TextStyle(color: textColor), maxLines: 2, decoration: InputDecoration(labelText: "Заметка".tr(widget.currentLang), labelStyle: TextStyle(color: textMuted), alignLabelWithHint: true, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: glassBorderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.blueAccent)))),
                        
                        // 🚀 ДОБАВЛЯЕМ ВЫБОР ИСПОЛНИТЕЛЯ ПРИ РЕДАКТИРОВАНИИ
                        if (task['workspace_id'] != null) ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            dropdownColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                            decoration: InputDecoration(
                              labelText: "Назначить на...".tr(widget.currentLang),
                              labelStyle: TextStyle(color: textMuted),
                              prefixIcon: const Icon(Icons.person_outline, color: Colors.blueAccent, size: 20),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: glassBorderColor)),
                            ),
                            value: selectedAssigneeId,
                            items: [
                              DropdownMenuItem(value: null, child: Text("Никто", style: TextStyle(color: textColor))),
                              ...(workspaceMembers[task['workspace_id']] ?? []).map((m) => DropdownMenuItem(
                                value: m['user_id'] as String,
                                child: Text(m['full_name'] ?? 'Участник', style: TextStyle(color: textColor)),
                              )).toList(),
                            ],
                            onChanged: (val) => setStateDialog(() => selectedAssigneeId = val),
                          ),
                        ],
                        // 🚀 КОНЕЦ ВСТАВКИ

                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(onPressed: () => Navigator.pop(context), child: Text("Отмена".tr(widget.currentLang), style: TextStyle(color: textMuted))),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                              onPressed: isSaving ? null : () async {
                                if (titleController.text.trim().isEmpty) return;
                                
                                setStateDialog(() => isSaving = true);

                                final newDateStr = selectedDate != null ? _formatDate(selectedDate!) : null;
                                
                                if (newDateStr != null && newDateStr != task['due_date']) {
                                  final dayCount = tasks.where((t) => t['due_date'] == newDateStr && t['parent_id'] == null).length;
                                  if (dayCount >= AppConfig.dailyTaskLimit) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Достигнут лимит (25) на день!")));
                                    setStateDialog(() => isSaving = false);
                                    return;
                                  }
                                }

                                await _updateTaskData(task['id'], {
                                  "title": titleController.text.trim(),
                                  "due_date": newDateStr,
                                  "due_time": selectedTime != null ? "${selectedTime!.hour.toString().padLeft(2,'0')}:${selectedTime!.minute.toString().padLeft(2,'0')}" : null,
                                  "note": noteController.text.trim().isNotEmpty ? noteController.text.trim() : null,
                                  "priority": selectedPriority,
                                  "tags": tagsController.text.trim().isNotEmpty ? tagsController.text.trim() : null,
                                  "recurrence": selectedRecurrence == 'none' ? null : selectedRecurrence,
                                  "is_completed": task['is_completed'] ?? false, 
                                  "parent_id": task['parent_id'],
                                  "assigned_to": selectedAssigneeId, // <--- ДОБАВИЛИ ЭТУ СТРОЧКУ
                                });
                                
                                if (context.mounted) Navigator.of(context).pop(); 
                                if (context.mounted) setStateDialog(() => isSaving = false);
                              },
                              child: isSaving 
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Text("Сохранить".tr(widget.currentLang), style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                )
              ),
            ),
          );
        });
      },
    );
  }

  void _showTaskDetailsDialog(Map<String, dynamic> task) {
    // Контроллеры для подзадач и чата
    final TextEditingController subtaskController = TextEditingController();
    final TextEditingController commentController = TextEditingController();
    List<Map<String, dynamic>> comments = [];
    bool isCommentsLoaded = false;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          
          // Загружаем комментарии (чат)
          if (!isCommentsLoaded) {
            isCommentsLoaded = true;
            Supabase.instance.client
                .from('task_comments')
                .select()
                .eq('task_id', task['id'])
                .order('created_at', ascending: true)
                .then((data) {
              if (context.mounted) {
                setStateDialog(() {
                  comments = List<Map<String, dynamic>>.from(data);
                });
              }
            });
          }

          // Вычисляем подзадачи (чек-лист)
          final subtasks = tasks.where((t) => t['parent_id'] == task['id']).toList();
          
          return Center(
            child: Material(
              color: Colors.transparent,
              child: _buildGlassContainer(
                padding: const EdgeInsets.all(32),
                child: SizedBox(
                  width: 450, 
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Детали задачи".tr(widget.currentLang), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textMuted, letterSpacing: 1.2)),
                            IconButton(icon: Icon(Icons.close, color: textMuted), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => Navigator.pop(context))
                          ]
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            if (task['priority'] != null && task['priority'] != 'none') Container(margin: const EdgeInsets.only(right: 12), width: 14, height: 14, decoration: BoxDecoration(shape: BoxShape.circle, color: _getPriorityColor(task['priority']), boxShadow: [BoxShadow(color: _getPriorityColor(task['priority']).withOpacity(0.5), blurRadius: 8)])),
                            Expanded(child: Text(task['title'] ?? '', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: textColor))),
                          ],
                        ),
                        if (task['tags'] != null && task['tags'].toString().trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            children: task['tags'].toString().split(',').map((t) => GestureDetector(onTap: () { Navigator.pop(context); setState(() => activeTagFilter = t.trim()); }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: highlightColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.blueAccent.withOpacity(0.4))), child: Text("#${t.trim()}", style: const TextStyle(fontSize: 13, color: Colors.blueAccent, fontWeight: FontWeight.bold))), )).toList(),
                          )
                        ],
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.event, color: Colors.blueAccent, size: 20)), 
                            const SizedBox(width: 12),
                            Text("${task['due_date'] ?? 'Входящие (Без даты)'.tr(widget.currentLang)}  •  ${task['due_time'] ?? 'Весь день'.tr(widget.currentLang)}", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
                            if (task['recurrence'] != null && task['recurrence'] != 'none') ...[const SizedBox(width: 12), const Icon(Icons.repeat, size: 18, color: Colors.orange)]
                          ],
                        ),
                        
                        // ИСПОЛНИТЕЛЬ
                        if (task['assigned_to'] != null) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.person, color: Colors.orangeAccent, size: 20)), 
                              const SizedBox(width: 12),
                              Builder(builder: (context) {
                                var members = workspaceMembers[task['workspace_id']] ?? [];
                                var member = members.firstWhere((m) => m['user_id'] == task['assigned_to'], orElse: () => <String, dynamic>{});
                                String name = member.isNotEmpty ? (member['full_name'] ?? 'Участник') : 'Неизвестно';
                                return Text("Исполнитель: $name", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor));
                              }),
                            ],
                          ),
                        ],

                        if (task['note'] != null && task['note'].toString().isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Container(
                            width: double.infinity, padding: const EdgeInsets.all(16), 
                            decoration: BoxDecoration(color: doneCardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: glassBorderColor)), 
                            child: MarkdownBody(
                              data: task['note'], 
                              styleSheet: MarkdownStyleSheet(
                                p: TextStyle(color: textColor, fontSize: 15, height: 1.5),
                                strong: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                                em: TextStyle(color: textColor, fontStyle: FontStyle.italic),
                                listBullet: const TextStyle(color: Colors.blueAccent),
                              )
                            )
                          ),
                        ],
                        const SizedBox(height: 32), Divider(color: glassBorderColor), const SizedBox(height: 16),
                        
                        // ЧЕК-ЛИСТ (ПОДЗАДАЧИ)
                        Row(
                          children: [
                            const Icon(Icons.checklist, color: Colors.blueAccent), const SizedBox(width: 8),
                            Text("Чек-лист".tr(widget.currentLang), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)), const Spacer(),
                            if (subtasks.isNotEmpty) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: glassColor, borderRadius: BorderRadius.circular(12)), child: Text("${subtasks.where((t)=>t['is_completed']==true).length} из ${subtasks.length}", style: TextStyle(color: textMuted, fontWeight: FontWeight.bold))),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (subtasks.isNotEmpty)
                          Column(
                            children: subtasks.map((subtask) {
                              bool isSubDone = subtask['is_completed'] == true;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(vertical: 4), decoration: BoxDecoration(color: isSubDone ? doneCardColor : cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: glassBorderColor)),
                                child: Row(
                                  children: [
                                    Checkbox(value: isSubDone, activeColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)), onChanged: (val) async { await _toggleTask(subtask); setStateDialog((){}); }),
                                    Expanded(child: Text(subtask['title'], style: TextStyle(fontSize: 15, decoration: isSubDone ? TextDecoration.lineThrough : TextDecoration.none, color: isSubDone ? textMuted : textColor))),
                                    IconButton(icon: Icon(Icons.close, size: 18, color: Colors.red[300]), onPressed: () async { await _deleteTask(subtask['id']); setStateDialog((){}); })
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        const SizedBox(height: 8),
                        // --- ЗАМЕНИ ЭТОТ БЛОК ---
Row(
  children: [
    Expanded(child: TextField(controller: subtaskController, style: TextStyle(color: textColor), decoration: InputDecoration(hintText: "Добавить пункт...".tr(widget.currentLang), hintStyle: TextStyle(color: textMuted), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: glassBorderColor)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: glassBorderColor)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), isDense: true), 
    onSubmitted: (text) { // <--- Убрали async
      if (text.trim().isEmpty) return; 
      subtaskController.clear(); 
      _createTaskManually({"title": text.trim(), "parent_id": task['id'], "is_completed": false}); // <--- Убрали await
      setStateDialog((){}); 
    })),
    const SizedBox(width: 8),
    IconButton(style: IconButton.styleFrom(backgroundColor: highlightColor, padding: const EdgeInsets.all(12)), icon: const Icon(Icons.add, color: Colors.blueAccent), 
    onPressed: () { // <--- Убрали async
      if (subtaskController.text.trim().isEmpty) return; 
      final text = subtaskController.text; 
      subtaskController.clear(); 
      _createTaskManually({"title": text.trim(), "parent_id": task['id'], "is_completed": false}); // <--- Убрали await
      setStateDialog((){}); 
    })
  ],
),
// --- КОНЕЦ ЗАМЕНЫ ---
                        
                        // ЧАТ (ОБСУЖДЕНИЕ)
                        const SizedBox(height: 32),
                        Divider(color: glassBorderColor),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Icon(Icons.chat_bubble_outline, color: Colors.blueAccent),
                            const SizedBox(width: 8),
                            Text("Обсуждение".tr(widget.currentLang), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        if (comments.isNotEmpty)
                          Container(
                            constraints: const BoxConstraints(maxHeight: 250),
                            margin: const EdgeInsets.only(bottom: 16),
                            child: SingleChildScrollView(
                              child: Column(
                                children: comments.map((c) {
                                  bool isMyComment = c['user_id'] == Supabase.instance.client.auth.currentUser?.id;
                                  String authorName = "Пользователь";
                                  String initial = "?";
                                  if (task['workspace_id'] != null) {
                                    var members = workspaceMembers[task['workspace_id']] ?? [];
                                    var member = members.firstWhere((m) => m['user_id'] == c['user_id'], orElse: () => <String, dynamic>{});
                                    if (member.isNotEmpty) {
                                      authorName = member['full_name'] ?? authorName;
                                      initial = authorName[0].toUpperCase();
                                    }
                                  } else if (isMyComment) {
                                     authorName = "Я";
                                     initial = "Я";
                                  }

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: isMyComment ? MainAxisAlignment.end : MainAxisAlignment.start,
                                      children: [
                                        if (!isMyComment)
                                          Padding(
                                            padding: const EdgeInsets.only(right: 8),
                                            child: CircleAvatar(radius: 14, backgroundColor: Colors.orangeAccent, child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                                          ),
                                        
                                        Flexible(
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: isMyComment ? Colors.blueAccent.withOpacity(0.1) : glassColor,
                                              borderRadius: BorderRadius.circular(12).copyWith(
                                                topLeft: !isMyComment ? const Radius.circular(0) : const Radius.circular(12),
                                                topRight: isMyComment ? const Radius.circular(0) : const Radius.circular(12),
                                              ),
                                              border: Border.all(color: isMyComment ? Colors.blueAccent.withOpacity(0.3) : glassBorderColor)
                                            ),
                                            child: Column(
                                              crossAxisAlignment: isMyComment ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                              children: [
                                                Text(authorName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isMyComment ? Colors.blueAccent : textMuted)),
                                                const SizedBox(height: 4),
                                                Text(c['text'] ?? '', style: TextStyle(fontSize: 14, color: textColor)),
                                              ],
                                            ),
                                          ),
                                        ),

                                        if (isMyComment)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 8),
                                            child: CircleAvatar(radius: 14, backgroundColor: Colors.blueAccent, child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                                          ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                          
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: commentController,
                                style: TextStyle(color: textColor),
                                decoration: InputDecoration(
                                  hintText: "Написать комментарий...".tr(widget.currentLang),
                                  hintStyle: TextStyle(color: textMuted),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: glassBorderColor)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: glassBorderColor)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  isDense: true
                                ),
                                onSubmitted: (text) async {
                                  if (commentController.text.trim().isEmpty) return;
                                  final submittedText = commentController.text.trim();
                                  commentController.clear();
                                  
                                  final user = Supabase.instance.client.auth.currentUser;
                                  if (user == null) return;
                                  
                                  final newComment = {
                                    'task_id': task['id'],
                                    'user_id': user.id,
                                    'text': submittedText,
                                  };
                                  
                                  setStateDialog(() {
                                     comments.add({...newComment, 'created_at': DateTime.now().toIso8601String()});
                                  });
                                  
                                  try {
                                    await Supabase.instance.client.from('task_comments').insert(newComment);
                                  } catch (e) {
                                    print("Ошибка отправки комментария: $e");
                                  }
                                }
                              )
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              style: IconButton.styleFrom(backgroundColor: Colors.blueAccent, padding: const EdgeInsets.all(12)),
                              icon: const Icon(Icons.send, color: Colors.white, size: 20),
                              onPressed: () async {
                                if (commentController.text.trim().isEmpty) return;
                                final text = commentController.text.trim();
                                commentController.clear();
                                
                                final user = Supabase.instance.client.auth.currentUser;
                                if (user == null) return;
                                
                                final newComment = {
                                  'task_id': task['id'],
                                  'user_id': user.id,
                                  'text': text,
                                };
                                
                                setStateDialog(() {
                                   comments.add({...newComment, 'created_at': DateTime.now().toIso8601String()});
                                });
                                
                                try {
                                  await Supabase.instance.client.from('task_comments').insert(newComment);
                                } catch (e) {
                                  print("Ошибка отправки комментария: $e");
                                }
                              }
                            )
                          ],
                        ),
                        
                        // КНОПКИ УПРАВЛЕНИЯ ЗАДАЧЕЙ
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton.icon(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), label: Text("Удалить".tr(widget.currentLang), style: TextStyle(color: Colors.redAccent)), onPressed: () { Navigator.of(context).pop(); _deleteTask(task['id']); }),
                            Row(
                              children: [
                                TextButton.icon(icon: const Icon(Icons.copy, color: Colors.blueAccent), label: Text("Дублировать".tr(widget.currentLang), style: TextStyle(color: Colors.blueAccent)), onPressed: () { setState(() { _taskToDuplicate = task; _isDuplicating = true; }); Navigator.of(context).pop(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Кликни на плюсик любого дня"))); }),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), icon: const Icon(Icons.edit, size: 18), label: Text("Изменить".tr(widget.currentLang), style: TextStyle(fontWeight: FontWeight.bold)), onPressed: () { Navigator.of(context).pop(); _showEditTaskDialog(task); }),
                              ]
                            )
                          ]
                        )
                      ],
                    ),
                  ),
                )
              ),
            ),
          );
        });
      }
    );
  }

  void _handlePlusTap(DateTime date, int currentDayTaskCount) {
    if (currentDayTaskCount >= AppConfig.dailyTaskLimit) { ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text("Лимит задач (100) исчерпан!".tr(widget.currentLang)), backgroundColor: Colors.redAccent)); return; }
    if (_isDuplicating && _taskToDuplicate != null) { _showManualAddDialog(preselectedDate: date, sourceTaskForDuplicate: _taskToDuplicate); } 
    else { _showManualAddDialog(preselectedDate: date); }
  }

  void _handleTaskTap(Map<String, dynamic> task) { _showTaskDetailsDialog(task); }

  void _handleTaskDropped({required Map<String, dynamic> task, required String targetDateStr, required int currentTargetTaskCount}) async {
    await _fetchTasks();
    _checkBurnoutWarning(targetDateStr); 
    if (currentTargetTaskCount >= AppConfig.dailyTaskLimit) { ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text("Лимит 100 задач!".tr(widget.currentLang)), backgroundColor: Colors.redAccent)); return; }
    if (HardwareKeyboard.instance.isControlPressed) {
      int? newTaskId = await _createTaskManually({"title": task['title'], "due_date": targetDateStr, "due_time": task['due_time'], "note": task['note'], "priority": task['priority'], "tags": task['tags'], "recurrence": task['recurrence'], "parent_id": task['parent_id'], "is_completed": false});
      if (newTaskId != null && task['parent_id'] == null) {
        final subtasksToCopy = tasks.where((t) => t['parent_id'] == task['id']).toList();
        for (var sub in subtasksToCopy) { await _createTaskManually({"title": sub['title'], "parent_id": newTaskId, "is_completed": false}); }
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Скопировано!".tr(widget.currentLang))));
    } else {
      if (task['due_date'] != targetDateStr) { _updateTaskData(task['id'], {"title": task['title'], "due_date": targetDateStr, "due_time": task['due_time'], "note": task['note'], "priority": task['priority'], "tags": task['tags'], "recurrence": task['recurrence'], "parent_id": task['parent_id'], "is_completed": task['is_completed'] ?? false}); }
    }
  }

Map<String, dynamic> _parseSmartInput(String text) {
    String title = text;
    String? time;
    List<String> tags = [];

    final timeReg = RegExp(r'\b(?:в\s)?([0-1]?[0-9]|2[0-3]):([0-5][0-9])\b', caseSensitive: false);
    final timeMatch = timeReg.firstMatch(title);
    if (timeMatch != null) {
      time = "${timeMatch.group(1)?.padLeft(2, '0')}:${timeMatch.group(2)}";
      title = title.replaceAll(timeMatch.group(0)!, '').trim(); 
    }

    final tagReg = RegExp(r'#([a-zA-Zа-яА-Я0-9_]+)');
    final tagMatches = tagReg.allMatches(title);
    for (var match in tagMatches) {
      tags.add(match.group(1)!);
      title = title.replaceAll(match.group(0)!, '').trim(); 
    }

    title = title.replaceAll(RegExp(r'\s+'), ' ').trim();

    return {
      'title': title,
      'time': time,
      'tags': tags.isNotEmpty ? tags.join(', ') : null
    };
  }

  @override
  Widget build(BuildContext context) {
    // 🚀 ВОТ ОНА - МАТЕМАТИКА АДАПТИВНОСТИ
    final double screenWidth = MediaQuery.of(context).size.width;
    _s = (screenWidth / 1920).clamp(0.4, 1.5); // Защищаем от сжатия в пыль и гигантизма

    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(bgImagePath),
          fit: BoxFit.cover,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: WindowBorder(
          color: Colors.transparent,
          width: 0,
          child: Column(
            children: [
              SizedBox(
                height: 32,
                child: WindowTitleBarBox(
                  child: Row(
                    children: [
                      Expanded(child: MoveWindow()),
                      WindowButtons(isDark: isDark)
                    ],
                  )
                )
              ),
              
              // 🚀 БОЛЬШЕ НИКАКОГО FITTEDBOX! РЕНДЕРИМ НАТИВНО И РЕЗКО
              Expanded(
                child: Row(
                  children: [
                    // Левое боковое меню (вынесено в виджет)
                    SidebarMenu(
                      isDark: widget.isDark,
                      scale: _s,
                      currentLang: widget.currentLang,
                      selectedMenu: selectedMenu,
                      menuItems: menuItems,
                      customFolders: customFolders,
                      workspaces: workspaces,
                      onMenuSelected: (menu) => setState(() => selectedMenu = menu),
                      onAddFolder: () => showAddFolderDialog(
                        context: context,
                        isDark: isDark,
                        textColor: textColor,
                        textMuted: textMuted,
                        glassBorderColor: glassBorderColor,
                        currentLang: widget.currentLang,
                        onFolderAdded: (folderName) {
                          setState(() => customFolders.add(folderName));
                          _settingsBox.put('custom_folders', json.encode(customFolders));
                        },
                      ),
                      onDeleteFolder: _deleteFolder,
                      onAddWorkspace: () => showCreateWorkspaceDialog(
                        context: context,
                        isDark: isDark,
                        scale: _s,
                        textColor: textColor,
                        textMuted: textMuted,
                        glassBorderColor: glassBorderColor,
                        currentLang: widget.currentLang,
                        onWorkspaceCreated: _fetchWorkspaces,
                      ),
                      onWorkspaceSelected: (id, menuKey) {
                        setState(() => selectedMenu = menuKey);
                        _fetchWorkspaceMembers(id);
                      },
                      userAccountBlock: _buildUserAccountBlock(),
                      buildGlassContainer: _buildGlassContainer,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.fromLTRB(40 * _s, 40 * _s, 40 * _s, 24 * _s),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Заголовок
                                Text(
                                  selectedMenu.startsWith('ws_') 
                                    ? workspaces.firstWhere((w) => w['id'].toString() == selectedMenu.substring(3), orElse: () => {'name': 'Команда'})['name'] 
                                    : selectedMenu.tr(widget.currentLang), 
                                  style: TextStyle(fontSize: 32 * _s, fontWeight: FontWeight.w900, letterSpacing: -1.0, color: textColor)
                                ),
                                
                                Row(
                                  children: [
                                    // Аватарки участников команды
                                    if (selectedMenu.startsWith('ws_')) ...[
                                      Builder(
                                        builder: (context) {
                                          int wsId = int.parse(selectedMenu.substring(3));
                                          List<Map<String, dynamic>> members = workspaceMembers[wsId] ?? [];
                                          
                                          return Row(
                                            children: members.map((m) {
                                              String rawName = m['full_name']?.toString().trim() ?? '';
                                              String name = rawName.isNotEmpty ? rawName : 'User';
                                              String initial = name[0].toUpperCase();
                                              
                                              // Статус Дзена
                                              bool isZen = zenStatuses[m['user_id'].toString()] == true;
                                              
                                              // 🚀 РАДАР ВЫГОРАНИЯ: Считаем активные задачи на сегодня
                                              String todayStr = _formatDate(DateTime.now());
                                              int todayTasksCount = tasks.where((t) => 
                                                t['workspace_id'] == wsId && 
                                                t['assigned_to'] == m['user_id'] && 
                                                t['due_date'] == todayStr && 
                                                t['is_completed'] != true &&
                                                t['parent_id'] == null // Считаем только главные задачи
                                              ).length;
                                              
                                              // Цветовая кодировка нагрузки
                                              Color heatColor = todayTasksCount >= 10 ? Colors.redAccent : (todayTasksCount >= 5 ? Colors.orangeAccent : Colors.green);
                                              
                                              return Padding(
                                                padding: EdgeInsets.only(right: 8 * _s),
                                                child: Tooltip(
                                                  // Обновляем подсказку при наведении
                                                  message: isZen ? "$name (В глубоком фокусе 🧘‍♂️)" : "$name (${m['role']})\n🔥 Задач на сегодня: $todayTasksCount",
                                                  child: Opacity(
                                                    opacity: isZen ? 0.4 : 1.0, 
                                                    child: Stack(
                                                      clipBehavior: Clip.none, // Позволяем бейджику вылезать за края
                                                      alignment: Alignment.center,
                                                      children: [
                                                        CircleAvatar(
                                                          radius: 18 * _s,
                                                          backgroundColor: isZen ? Colors.grey.shade600 : Colors.primaries[members.indexOf(m) % Colors.primaries.length].shade700,
                                                          child: Text(initial, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14 * _s)),
                                                        ),
                                                        if (isZen)
                                                          Icon(Icons.self_improvement, color: Colors.white.withOpacity(0.9), size: 20 * _s),
                                                          
                                                        // 🚀 РИСУЕМ БЕЙДЖИК НАГРУЗКИ
                                                        if (!isZen && todayTasksCount > 0)
                                                          Positioned(
                                                            bottom: -2,
                                                            right: -2,
                                                            child: Container(
                                                              padding: EdgeInsets.all(5 * _s),
                                                              decoration: BoxDecoration(
                                                                color: heatColor,
                                                                shape: BoxShape.circle,
                                                                border: Border.all(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, width: 2)
                                                              ),
                                                              child: Text(
                                                                todayTasksCount.toString(),
                                                                style: TextStyle(color: Colors.white, fontSize: 10 * _s, fontWeight: FontWeight.bold)
                                                              )
                                                            )
                                                          )
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          );
                                        }
                                      ),
                                      SizedBox(width: 8 * _s),
                                      
                                      // Кнопка "Пригласить"
                                      Padding(
                                        padding: EdgeInsets.only(right: 16 * _s),
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.orangeAccent.withOpacity(0.1),
                                            foregroundColor: Colors.orangeAccent,
                                            elevation: 0,
                                            padding: EdgeInsets.symmetric(horizontal: 16 * _s, vertical: 10 * _s),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12 * _s), side: const BorderSide(color: Colors.orangeAccent))
                                          ),
                                          icon: Icon(Icons.person_add_alt_1, size: 20 * _s),
                                          label: Text("Пригласить".tr(widget.currentLang), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 * _s)),
                                          onPressed: () => showInviteMemberDialog(
                                            context: context,
                                            workspaceId: int.parse(selectedMenu.substring(3)),
                                            isDark: isDark,
                                            scale: _s,
                                            textColor: textColor,
                                            textMuted: textMuted,
                                            glassBorderColor: glassBorderColor,
                                            currentLang: widget.currentLang,
                                          ),
                                        ),
                                      ),
                                    ],

                                    if (_isOffline)
                                      Padding(
                                        padding: EdgeInsets.only(right: 12 * _s),
                                        child: Icon(Icons.cloud_off, color: Colors.orangeAccent, size: 24 * _s),
                                      ),

                                    if (_pendingOpsCount > 0)
                                      Padding(
                                        padding: EdgeInsets.only(right: 12 * _s),
                                        child: Tooltip(
                                          message: "Несинхронизированных изменений: $_pendingOpsCount".tr(widget.currentLang),
                                          child: Icon(Icons.sync_problem, color: Colors.orangeAccent, size: 24 * _s),
                                        ),
                                      ),


                                    // 🚀 НОВАЯ КНОПКА СВИНЦОВОГО КУПОЛА
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _isMyZenActive ? Colors.deepPurpleAccent : Colors.transparent,
                                        foregroundColor: _isMyZenActive ? Colors.white : textMuted,
                                        elevation: 0,
                                        padding: EdgeInsets.symmetric(horizontal: 16 * _s, vertical: 12 * _s),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12 * _s), side: BorderSide(color: _isMyZenActive ? Colors.deepPurpleAccent : glassBorderColor))
                                      ),
                                      icon: Icon(Icons.self_improvement, size: 20 * _s),
                                      label: Text(_isMyZenActive ? "В фокусе".tr(widget.currentLang) : "Фокусирование".tr(widget.currentLang), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15 * _s)),
                                      onPressed: _toggleZenMode,
                                    ),
                                    SizedBox(width: 12 * _s),
                                    // 🚀 КНОПКА ПУЛЬСА КОМАНДЫ (Только внутри воркспейса)
                                    if (selectedMenu.startsWith('ws_')) ...[
                                      IconButton(
                                        icon: Icon(Icons.monitor_heart_outlined, color: Colors.redAccent, size: 26 * _s),
                                        tooltip: "Пульс команды".tr(widget.currentLang),
                                        onPressed: () => showTeamPulseDialog(
                                          context: context,
                                          wsId: int.parse(selectedMenu.substring(3)),
                                          scale: _s,
                                          currentLang: widget.currentLang,
                                          textColor: textColor,
                                          textMuted: textMuted,
                                          tasks: tasks,
                                          workspaceMembers: workspaceMembers,
                                          formatDate: _formatDate,
                                          buildGlassContainer: _buildGlassContainer,
                                        ),
                                      ),
                                      SizedBox(width: 4 * _s),
                                    ],
                                    IconButton(icon: Icon(Icons.refresh, color: textMuted, size: 26 * _s), onPressed: _fetchTasks),
                                    SizedBox(width: 4 * _s),
                                    IconButton(
                                      icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, color: isDark ? Colors.yellow : textMuted, size: 26 * _s),
                                      onPressed: widget.toggleTheme,
                                    ),
                                    SizedBox(width: 16 * _s),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(backgroundColor: rightPanelState == 'ai' ? highlightColor : Colors.blueAccent.withOpacity(0.9), foregroundColor: rightPanelState == 'ai' ? Colors.redAccent : Colors.white, padding: EdgeInsets.symmetric(horizontal: 20 * _s, vertical: 12 * _s), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12 * _s)), elevation: 0, side: BorderSide(color: rightPanelState == 'ai' ? Colors.red[300]! : Colors.transparent)),
                                      icon: Icon(rightPanelState == 'ai' ? Icons.close : Icons.auto_awesome, size: 20 * _s),
                                      label: Text(rightPanelState == 'ai' ? "Закрыть чат".tr(widget.currentLang) : "AI Ассистент".tr(widget.currentLang), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15 * _s)),
                                      onPressed: () => setState(() => rightPanelState = rightPanelState == 'ai' ? 'none' : 'ai'),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                          if (activeTagFilter != null)
                            Padding(
                              padding: EdgeInsets.fromLTRB(40 * _s, 0, 40 * _s, 24 * _s),
                              child: Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 16 * _s, vertical: 8 * _s), decoration: BoxDecoration(color: highlightColor, borderRadius: BorderRadius.circular(24 * _s), border: Border.all(color: Colors.blueAccent.withOpacity(0.4))),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.filter_alt, size: 18 * _s, color: Colors.blueAccent), SizedBox(width: 8 * _s),
                                        Text("Тег: #$activeTagFilter".tr(widget.currentLang), style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 15 * _s)), SizedBox(width: 12 * _s),
                                        InkWell(onTap: () => setState(() => activeTagFilter = null), child: Container(padding: EdgeInsets.all(4 * _s), decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.blueAccent.withOpacity(0.6)), child: Icon(Icons.close, size: 14 * _s, color: Colors.white),))
                                      ],
                                    )
                                  ),
                                ],
                              )
                            ),
                          // Переходим к главному контенту (Через вынесенный виджет)
                          Expanded(
                            child: Builder(builder: (context) {
                              final taskCardBuilders = TaskCardBuilders(
                                isDark: widget.isDark,
                                scale: _s,
                                workspaceMembers: workspaceMembers,
                                getPriorityColor: _getPriorityColor,
                                getSubtaskStats: _getSubtaskStats,
                                isOverdue: _isOverdue,
                                onToggle: _toggleTask,
                                onDelete: _deleteTask,
                                onTap: _handleTaskTap,
                                onTagTap: (tag) => setState(() => activeTagFilter = tag),
                                buildGlassContainer: _buildGlassContainer,
                              );
                              return MainContentArea(
                              selectedMenu: selectedMenu,
                              currentLang: widget.currentLang,
                              customFolders: customFolders,
                              filteredTasks: filteredTasks,
                              isDark: widget.isDark,
                              scale: _s, 
                              currentCalendarDate: _currentCalendarDate,
                              onCalendarDateChanged: (newDate) {
                                setState(() {
                                  _currentCalendarDate = newDate;
                                });
                              },
                              onReorderTasks: (oldIndex, newIndex, targetTasks) {
                                setState(() {
                                  if (newIndex > oldIndex) newIndex -= 1;
                                  final item = targetTasks.removeAt(oldIndex);
                                  targetTasks.insert(newIndex, item);
                                });
                              },
                              onTaskDropped: (task, targetDateStr, currentTargetTaskCount) {
                                _handleTaskDropped(task: task, targetDateStr: targetDateStr, currentTargetTaskCount: currentTargetTaskCount);
                              },
                              onPlusTap: (targetDate, currentTaskCount) {
                                _handlePlusTap(targetDate, currentTaskCount);
                              },
                              buildListTaskCard: taskCardBuilders.buildListTaskCard,
                              buildBoardTaskCardExpanded: taskCardBuilders.buildBoardTaskCardExpanded,
                              buildCalendarTaskCard: taskCardBuilders.buildCalendarTaskCard,
                              buildGlassContainer: _buildGlassContainer,
                              buildStatisticsDashboard: () => StatisticsDashboard(
                                tasks: tasks,
                                currentLang: widget.currentLang,
                                textColor: textColor,
                                textMuted: textMuted,
                                isOverdue: _isOverdue,
                                parseDate: _parseDate,
                                buildGlassContainer: _buildGlassContainer,
                              ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300), curve: Curves.easeInOut, width: rightPanelState != 'none' ? 360 * _s : 0, 
                      child: rightPanelState == 'none' ? const SizedBox.shrink() : _buildGlassContainer(
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), bottomLeft: Radius.circular(24)),
                        margin: EdgeInsets.zero,
                        child: rightPanelState == 'ai' ? AiChatPanel(
                          currentLang: widget.currentLang,
                          textColor: textColor,
                          textMuted: textMuted,
                          glassBorderColor: glassBorderColor,
                          chatBubbleAi: chatBubbleAi,
                          chatInput: chatInput,
                          chatMessages: chatMessages,
                          isAiTyping: isAiTyping,
                          isListening: _isListening,
                          controller: _aiChatController,
                          onToggleListening: _toggleListening,
                          onSend: _sendTaskToAI,
                        ) : const SizedBox.shrink()
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: Padding(
          padding: EdgeInsets.only(right: rightPanelState != 'none' ? 360.0 * _s : 0.0, bottom: 24.0 * _s),
          child: FloatingActionButton.extended(
            onPressed: () { if (_isDuplicating && _taskToDuplicate != null) { _showManualAddDialog(preselectedDate: DateTime.now(), sourceTaskForDuplicate: _taskToDuplicate); } else { _showManualAddDialog(); } },
            backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, elevation: 8, icon: Icon(Icons.add, size: 26 * _s), label: Text("Создать задачу".tr(widget.currentLang), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16 * _s)),
          ),
        ),
      ),
    );
  }

  void _showAccountSettingsDialog() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    String fullName = user.userMetadata?['full_name'] ?? '';
    String? avatarUrl = user.userMetadata?['avatar_url'];
    final email = user.email ?? '';

    final providers = user.appMetadata['providers'] as List<dynamic>? ?? [];
    final hasPasswordAuth = providers.contains('email'); 

    final nameController = TextEditingController(text: fullName);
    final oldPasswordController = TextEditingController(); 
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    bool isLoading = false;
    bool isChangingPassword = false;
    bool isAutostart = false; // Состояние автозапуска

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          
          // Получаем актуальный статус автозагрузки при открытии
          launchAtStartup.isEnabled().then((value) {
            if (mounted && isAutostart != value) {
              setStateDialog(() => isAutostart = value);
            }
          });

          Future<void> pickAndUpload() async {
            FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
            if (result != null && result.files.single.bytes != null) {
              setStateDialog(() => isLoading = true);
              try {
                final bytes = result.files.single.bytes!;
                final ext = result.files.single.extension ?? 'png';
                final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.$ext';
                
                await Supabase.instance.client.storage.from('avatars').uploadBinary(fileName, bytes);
                final newUrl = Supabase.instance.client.storage.from('avatars').getPublicUrl(fileName);
                
                await Supabase.instance.client.auth.updateUser(UserAttributes(data: {'avatar_url': newUrl}));
                
                setStateDialog(() => avatarUrl = newUrl);
                setState((){}); 
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Аватар обновлен!'.tr(widget.currentLang)), backgroundColor: Colors.green));
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'.tr(widget.currentLang)), backgroundColor: Colors.redAccent));
              } finally {
                setStateDialog(() => isLoading = false);
              }
            }
          }

          Future<void> deleteAvatar() async {
            setStateDialog(() => isLoading = true);
            try {
              await Supabase.instance.client.auth.updateUser(UserAttributes(data: {'avatar_url': null}));
              setStateDialog(() => avatarUrl = null);
              setState((){}); 
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Аватарка удалена!'.tr(widget.currentLang)), backgroundColor: Colors.green));
            } catch (e) {
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'.tr(widget.currentLang)), backgroundColor: Colors.redAccent));
            } finally {
              setStateDialog(() => isLoading = false);
            }
          }

          return Center(
            child: Material(
              color: Colors.transparent,
              child: _buildGlassContainer(
                padding: const EdgeInsets.all(32),
                child: SizedBox(
                  width: 400,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Настройки".tr(widget.currentLang), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                            if (isLoading) 
                              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            else
                              IconButton(icon: Icon(Icons.close, color: textMuted), onPressed: () => Navigator.pop(context))
                          ]
                        ),
                        const SizedBox(height: 24),
                        
                        GestureDetector(
                          onTap: isLoading ? null : () {
                            bool hasAvatar = avatarUrl != null && avatarUrl!.isNotEmpty;
                            showDialog(
                              context: context,
                              builder: (dialogCtx) => AlertDialog(
                                backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                title: Text("Фото профиля".tr(widget.currentLang), style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.upload, color: Colors.blueAccent),
                                      title: Text("Загрузить новое".tr(widget.currentLang), style: TextStyle(color: textColor)),
                                      onTap: () {
                                        Navigator.pop(dialogCtx);
                                        pickAndUpload();
                                      },
                                    ),
                                    if (hasAvatar) ...[
                                      const Divider(),
                                      ListTile(
                                        leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                        title: Text("Удалить текущее".tr(widget.currentLang), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                        onTap: () {
                                          Navigator.pop(dialogCtx);
                                          deleteAvatar();
                                        },
                                      ),
                                    ]
                                  ],
                                ),
                              )
                            );
                          },
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CircleAvatar(
                                radius: 45,
                                backgroundColor: isDark ? Colors.black45 : Colors.white54,
                                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                                child: avatarUrl == null 
                                  ? Text(fullName.isNotEmpty ? fullName[0].toUpperCase() : '?', style: TextStyle(fontSize: 32, color: textMuted))
                                  : null,
                              ),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle, border: Border.all(color: glassBorderColor, width: 2)),
                                child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: nameController, style: TextStyle(color: textColor),
                                decoration: InputDecoration(labelText: "Никнейм".tr(widget.currentLang), labelStyle: TextStyle(color: textMuted), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: glassBorderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.blueAccent)), isDense: true)
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: highlightColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
                              onPressed: isLoading ? null : () async {
                                if (nameController.text.trim().isEmpty) return;
                                setStateDialog(() => isLoading = true);
                                try {
                                  await Supabase.instance.client.auth.updateUser(UserAttributes(data: {'full_name': nameController.text.trim()}));
                                  setState((){}); 
                                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Имя сохранено!'.tr(widget.currentLang))));
                                } catch (e) {
                                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'.tr(widget.currentLang)), backgroundColor: Colors.redAccent));
                                } finally {
                                  setStateDialog(() => isLoading = false);
                                }
                              },
                              child: Text("Сохранить".tr(widget.currentLang), style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold))
                            )
                          ],
                        ),
                        const SizedBox(height: 16),

                        // --- ПЕРЕКЛЮЧАТЕЛЬ АВТОЗАПУСКА ---
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.rocket_launch, color: textColor, size: 20),
                                const SizedBox(width: 8),
                                Text("Автозапуск с Windows".tr(widget.currentLang), style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Switch(
                              value: isAutostart,
                              activeColor: Colors.blueAccent,
                              onChanged: (val) async {
                                setStateDialog(() => isAutostart = val);
                                if (val) {
                                  await launchAtStartup.enable();
                                } else {
                                  await launchAtStartup.disable();
                                }
                              },
                            )
                          ]
                        ),
                        const SizedBox(height: 16),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.language, color: textColor, size: 20),
                                const SizedBox(width: 8),
                                Text("Язык".tr(widget.currentLang), style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Container(
                              height: 36,
                              decoration: BoxDecoration(
                                color: glassColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: glassBorderColor)
                              ),
                              child: ToggleButtons(
                                borderRadius: BorderRadius.circular(12),
                                borderColor: Colors.transparent, selectedBorderColor: Colors.transparent,
                                fillColor: Colors.blueAccent.withOpacity(0.2),
                                selectedColor: Colors.blueAccent, color: textMuted,
                                constraints: const BoxConstraints(minHeight: 36, minWidth: 48),
                                isSelected: [widget.currentLang == 'ru', widget.currentLang == 'en'],
                                onPressed: (index) {
                                  widget.changeLang(index == 0 ? 'ru' : 'en');
                                  Navigator.pop(context); 
                                },
                                children: const [
                                  Text("RU", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text("EN", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                ],
                              ),
                            )
                          ]
                        ),
                        const SizedBox(height: 16),

                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16), 
                              side: BorderSide(color: Colors.blueAccent.withOpacity(0.5)), 
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                            ),
                            icon: const Icon(Icons.telegram, color: Colors.blueAccent, size: 20),
                            label: Text("Поддержка".tr(widget.currentLang), style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                            onPressed: () async {
                              final Uri url = Uri.parse(AppConfig.telegramSupportUrl);
                              if (await canLaunchUrl(url)) {
                                await launchUrl(url, mode: LaunchMode.externalApplication);
                              } else {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Не удалось открыть Telegram".tr(widget.currentLang)), backgroundColor: Colors.redAccent)
                                  );
                                }
                              }
                            }
                          ),
                        ),

                        const SizedBox(height: 16),

                        TextField(
                          controller: TextEditingController(text: email), style: TextStyle(color: textMuted), enabled: false,
                          decoration: InputDecoration(labelText: "Email", labelStyle: TextStyle(color: textMuted), disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: glassBorderColor.withOpacity(0.5))), filled: true, fillColor: isDark ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.05), isDense: true)
                        ),
                        const SizedBox(height: 24),
                        Divider(color: glassBorderColor),
                        const SizedBox(height: 16),

                        if (!isChangingPassword)
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), side: BorderSide(color: glassBorderColor), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                              icon: Icon(hasPasswordAuth ? Icons.lock_outline : Icons.vpn_key_outlined, color: textColor, size: 20),
                              label: Text(hasPasswordAuth ? "Изменить пароль".tr(widget.currentLang) : "Установить пароль".tr(widget.currentLang), style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                              onPressed: () => setStateDialog(() => isChangingPassword = true)
                            ),
                          )
                        else
                          Column(
                            children: [
                              if (hasPasswordAuth) ...[
                                TextField(controller: oldPasswordController, obscureText: true, style: TextStyle(color: textColor), decoration: InputDecoration(labelText: "Текущий пароль".tr(widget.currentLang), labelStyle: TextStyle(color: textMuted), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: glassBorderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.redAccent.withOpacity(0.5))), isDense: true)),
                                const SizedBox(height: 12),
                              ],
                              
                              TextField(controller: newPasswordController, obscureText: true, style: TextStyle(color: textColor), decoration: InputDecoration(labelText: "Новый пароль".tr(widget.currentLang), labelStyle: TextStyle(color: textMuted), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: glassBorderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.blueAccent)), isDense: true)),
                              const SizedBox(height: 12),
                              TextField(controller: confirmPasswordController, obscureText: true, style: TextStyle(color: textColor), decoration: InputDecoration(labelText: "Подтвердите пароль".tr(widget.currentLang), labelStyle: TextStyle(color: textMuted), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: glassBorderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.blueAccent)), isDense: true)),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(child: TextButton(onPressed: () => setStateDialog(() { isChangingPassword = false; oldPasswordController.clear(); newPasswordController.clear(); confirmPasswordController.clear(); }), child: Text("Отмена".tr(widget.currentLang), style: TextStyle(color: textMuted)))),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)), 
                                      onPressed: isLoading ? null : () async {
                                        final oldPass = oldPasswordController.text;
                                        final newPass = newPasswordController.text;
                                        final confPass = confirmPasswordController.text;

                                        if (newPass != confPass) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Новые пароли не совпадают!'.tr(widget.currentLang)), backgroundColor: Colors.redAccent)); return; }
                                        if (newPass.length < 6) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Минимум 6 символов!'.tr(widget.currentLang)), backgroundColor: Colors.redAccent)); return; }
                                        
                                        setStateDialog(() => isLoading = true);
                                        try { 
                                          if (hasPasswordAuth) {
                                            if (oldPass.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Введите текущий пароль!'.tr(widget.currentLang)), backgroundColor: Colors.redAccent)); setStateDialog(() => isLoading = false); return; }
                                            if (oldPass == newPass) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Новый пароль должен отличаться!'.tr(widget.currentLang)), backgroundColor: Colors.orangeAccent)); setStateDialog(() => isLoading = false); return; }
                                            
                                            await Supabase.instance.client.auth.signInWithPassword(email: email, password: oldPass);
                                          }

                                          await Supabase.instance.client.auth.updateUser(UserAttributes(password: newPass)); 
                                          
                                          setStateDialog(() { isChangingPassword = false; oldPasswordController.clear(); newPasswordController.clear(); confirmPasswordController.clear(); }); 
                                          
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(hasPasswordAuth ? 'Пароль успешно изменен!'.tr(widget.currentLang) : 'Пароль установлен! Теперь вы можете входить по Email.'.tr(widget.currentLang)), backgroundColor: Colors.green)); 
                                            if (!hasPasswordAuth) Navigator.of(context).pop();
                                          }
                                        } on AuthException catch (e) {
                                          if (context.mounted) {
                                            if (e.message.contains('Invalid login credentials')) {
                                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Неверный текущий пароль!'.tr(widget.currentLang)), backgroundColor: Colors.redAccent));
                                            } else {
                                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: ${e.message}'.tr(widget.currentLang)), backgroundColor: Colors.redAccent));
                                            }
                                          }
                                        } catch (e) { 
                                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'.tr(widget.currentLang)), backgroundColor: Colors.redAccent)); 
                                        } finally { 
                                          setStateDialog(() => isLoading = false); 
                                        }
                                      }, 
                                      child: Text("Сохранить".tr(widget.currentLang), style: TextStyle(fontWeight: FontWeight.bold))
                                    )
                                  ),
                                ]
                              )
                            ]
                          ),

                        const SizedBox(height: 24),
                        
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.withOpacity(0.1), foregroundColor: Colors.redAccent, padding: const EdgeInsets.symmetric(vertical: 16), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.redAccent))),
                            icon: const Icon(Icons.exit_to_app, size: 20),
                            label: Text("Выйти из аккаунта".tr(widget.currentLang), style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () async {
                              if (context.mounted) Navigator.of(context).pop();
                              await Supabase.instance.client.auth.signOut();
                            }
                          ),
                        )
                      ],
                    ),
                  ),
                )
              ),
            ),
          );
        });
      }
    );
  }

  bool _isOverdue(Map<String, dynamic> task) {
    if (task['is_completed'] == true) return false; 
    if (task['due_date'] == null) return false;     

    final date = _parseDate(task['due_date']);
    if (date == null) return false;

    int hour = 23;
    int minute = 59;

    if (task['due_time'] != null && task['due_time'].toString().contains(':')) {
      final parts = task['due_time'].split(':');
      hour = int.tryParse(parts[0]) ?? 23;
      minute = int.tryParse(parts[1]) ?? 59;
    }

    final taskDateTime = DateTime(date.year, date.month, date.day, hour, minute);
    return DateTime.now().isAfter(taskDateTime); 
  }
}
