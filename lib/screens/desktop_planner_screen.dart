import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:local_notifier/local_notifier.dart';

import '../core/app_settings.dart';
import '../core/config.dart';
import '../core/localization.dart';
import '../core/tags.dart';
import '../core/priority.dart';
import '../core/theme/design_tokens.dart';
import '../services/browser_notification.dart';
import '../services/task_service.dart';
import '../widgets/clarify_button.dart';
import '../widgets/clarify_glass.dart';
import '../widgets/clarify_surface.dart';
import 'package:animations/animations.dart';
import '../widgets/ambient_background.dart';
import '../widgets/clarify_toast.dart';
import '../widgets/main_content_area.dart';
import '../widgets/user_profile_modal.dart';
import '../widgets/sidebar_menu.dart';
import '../widgets/window_buttons.dart';
import 'mobile/mobile_planner_shell.dart';
import '../widgets/task_cards.dart';
import '../widgets/statistics_dashboard.dart';
import '../widgets/ai_chat_panel.dart';
import '../dialogs/workspace_dialogs.dart';
import '../dialogs/team_pulse_dialog.dart';
import '../dialogs/search_dialog.dart';
import '../widgets/command_palette.dart';
import '../dialogs/manual_add_dialog.dart';
import '../dialogs/edit_task_dialog.dart';
import '../dialogs/task_details_dialog.dart';
import '../dialogs/account_settings_dialog.dart';

/// Бросается _parseTextToTasks, когда /tasks/parse отвечает не-200 —
/// отдельный тип нужен, чтобы отличать "сервер ответил ошибкой" от
/// "нет связи" в UI (десктоп и мобильный AI-экран).
class AiParseHttpException implements Exception {
  final int statusCode;
  const AiParseHttpException(this.statusCode);
}

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

  // Guard от гонки при повторном действии до ответа сети — id мутирующего
  // действия (не самой задачи, одна задача может участвовать в разных
  // одновременных действиях) добавляется сюда на время запроса и снимается
  // в finally, второй вызов с тем же id, пока первый не завершился, игнорируется.
  final Set<String> _pendingActionIds = {};

  Future<void> _guardedAction(String actionId, Future<void> Function() action) async {
    if (_pendingActionIds.contains(actionId)) return;
    _pendingActionIds.add(actionId);
    try {
      await action();
    } finally {
      _pendingActionIds.remove(actionId);
    }
  }

  List<Map<String, dynamic>> tasks = [];
  Map<String, dynamic>? _taskToDuplicate;
  bool _isDuplicating = false;

  String selectedMenu = 'Мой день';
  // Переход "написать" из карточки друга — открывает Сообщения сразу с этим
  // диалогом (см. MainContentArea.onOpenDirectChat/MessengerShell).
  String? _pendingChatPartnerId;
  String? _pendingChatPartnerName;
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
  String? activePriorityFilter;
  bool sortByPriority = false;

  late Box _settingsBox;

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
            'zen_until': newState ? DateTime.now().add(Duration(minutes: AppSettings.zenDurationMinutes)).toIso8601String() : null
          })
          .eq('user_id', user.id);
          
      setState(() => _isMyZenActive = newState);
      
      if (mounted) {
        ClarifyToast.show(
          context,
          (newState ? "Фокусирование включено! Уведомления заглушены" : "Фокусирование выключено!").tr(widget.currentLang),
          variant: ClarifyToastVariant.info,
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
  final List<String> menuItems = ['Мой день', 'Следующие 7 дней', 'Все задачи', 'Календарь', 'Входящие', 'Проекты', 'Друзья', 'Сообщения', 'Статистика'];
  final List<String> weekdaysRu = ['понедельник', 'вторник', 'среда', 'четверг', 'пятница', 'суббота', 'воскресенье'];

  bool get isDark => widget.isDark;
  Color get bgColor => Colors.transparent;
  ClarifyTokens get _tokens => isDark ? ClarifyTokens.dark : ClarifyTokens.light;
  Color get glassColor => _tokens.surface.withValues(alpha: isDark ? 0.55 : 0.7);
  Color get glassBorderColor => _tokens.border;
  Color get panelColor => glassColor;
  Color get cardColor => glassColor;
  Color get doneCardColor => _tokens.surfaceSunken.withValues(alpha: isDark ? 0.7 : 0.85);
  Color get borderColor => glassBorderColor;
  Color get borderStrong => _tokens.borderStrong;
  Color get textColor => _tokens.text;
  Color get textMuted => _tokens.text2;
  Color get highlightColor => _tokens.accentSoft;
  Color get chatBubbleAi => _tokens.surface2.withValues(alpha: isDark ? 0.6 : 0.8);
  Color get chatInput => _tokens.surfaceSunken.withValues(alpha: isDark ? 0.7 : 0.85);

  String get _userFullName => Supabase.instance.client.auth.currentUser?.userMetadata?['full_name']?.toString() ?? '';
  String get _userInitial => _userFullName.isNotEmpty ? _userFullName[0].toUpperCase() : '?';

  Widget _buildStatisticsDashboardWidget() => StatisticsDashboard(
        tasks: tasks,
        workspaces: workspaces,
        currentLang: widget.currentLang,
        textColor: textColor,
        textMuted: textMuted,
        isOverdue: _isOverdue,
        parseDate: _parseDate,
        getPriorityColor: _getPriorityColor,
        buildGlassContainer: _buildGlassContainer,
      );

  Widget _buildGlassContainer({required Widget child, BorderRadius? borderRadius, EdgeInsetsGeometry? padding, EdgeInsetsGeometry? margin, Color? customColor}) {
    return ClarifyGlass(borderRadius: borderRadius, padding: padding, margin: margin, customColor: customColor, child: child);
  }

  // Свёрнутый вариант — только аватар (по решению из этого же диалога:
  // "только аватар, имя/Настройки скрыты").
  Widget _buildUserAccountBlockCollapsed() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return const SizedBox.shrink();

    final metadata = user.userMetadata ?? {};
    final fullName = metadata['full_name']?.toString() ?? 'Без имени';
    final avatarUrl = metadata['avatar_url']?.toString();
    final initial = fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8 * _s),
      child: Center(
        child: Tooltip(
          message: "$fullName — ${"Настройки".tr(widget.currentLang)}",
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _showAccountSettingsDialog,
              hoverColor: _tokens.accent.withValues(alpha: 0.06),
              child: Padding(
                padding: EdgeInsets.all(4 * _s),
                child: CircleAvatar(
                  radius: 20 * _s,
                  backgroundColor: isDark ? Colors.black45 : Colors.white54,
                  backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null
                      ? Text(initial, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18 * _s))
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Храним дату (ДД.ММ.ГГГГ), для которой уже показывали обзор — а не просто bool,
  // иначе сводка не повторится на следующий день без перезапуска приложения.
  String? _dailyReviewShownForDate;

  // Даты, для которых уже показали предупреждение о перегрузке — чтобы не спамить
  // диалогом на каждой 11-й, 12-й и т.д. задаче после смены `== 10` на `>= 10`.
  final Set<String> _burnoutWarnedDates = {};

  @override
  void initState() {
    super.initState();
    _settingsBox = Hive.box('settings');

    _loadLocalData();
    _fetchTasks();    
    _fetchWorkspaces(); 
    _fetchZenStatuses(); // <--- Добавили запуск загрузки статусов
    _initRealtime(); // <--- ВОТ ЭТА НОВАЯ СТРОЧКА
    
    _initSpeech();
    _initGlobalHotkeys();
  }

  void _loadLocalData() {
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
    await hotKeyManager.register(searchKey, keyDownHandler: (hotKey) => showSearchDialog(
      context: context,
      currentLang: widget.currentLang,
      textColor: textColor,
      textMuted: textMuted,
      tasks: tasks,
      onTaskSelected: _showTaskDetailsDialog,
      buildGlassContainer: _buildGlassContainer,
    ));

    HotKey commandPaletteKey = HotKey(key: PhysicalKeyboardKey.keyK, modifiers: [HotKeyModifier.control], scope: HotKeyScope.inapp);
    await hotKeyManager.register(commandPaletteKey, keyDownHandler: (hotKey) => _showCommandPalette());
  }

  void _showCommandPalette() {
    showCommandPalette(
      context: context,
      currentLang: widget.currentLang,
      textColor: textColor,
      textMuted: textMuted,
      isDark: isDark,
      tasks: tasks,
      menuItems: menuItems,
      onNavigate: (menu) => setState(() => selectedMenu = menu),
      onCreateTask: () => _showManualAddDialog(),
      onToggleTheme: widget.toggleTheme,
      onOpenSettings: _showAccountSettingsDialog,
      onAskAi: (query) => setState(() {
        rightPanelState = 'ai';
        _aiChatController.text = query;
      }),
      onTaskSelected: _showTaskDetailsDialog,
      buildGlassContainer: _buildGlassContainer,
    );
  }

  // Локальный статус доски проекта (Не начато/В работе) — нет поля в БД под это,
  // поэтому не синхронизируется между устройствами; "Готово" считается отдельно
  // по реальному is_completed. См. lib/widgets/project_kanban_board.dart.
  Map<String, String> _readKanbanStatusMap() {
    final raw = _settingsBox.get('kanban_status');
    if (raw == null) return {};
    return Map<String, String>.from(json.decode(raw));
  }

  String _getLocalKanbanStatus(dynamic taskId) => _readKanbanStatusMap()[taskId.toString()] ?? 'todo';

  void _setLocalKanbanStatus(dynamic taskId, String status) {
    setState(() {
      final map = _readKanbanStatusMap();
      map[taskId.toString()] = status;
      _settingsBox.put('kanban_status', json.encode(map));
    });
  }

  // Иконки авто-папок проектов (тег → ключ из kPickableProjectIcons) —
  // локально, не через Supabase: у тегов нет своей строки в базе, это личные
  // ярлыки одного пользователя (см. REDESIGN_V3_PLAN.md §5.11).
  Map<String, String> _readProjectIconKeys() {
    final raw = _settingsBox.get('project_icons');
    if (raw == null) return {};
    return Map<String, String>.from(json.decode(raw));
  }

  void _setProjectIcon(String tag, String iconKey) {
    setState(() {
      final map = _readProjectIconKeys();
      map[tag] = iconKey;
      _settingsBox.put('project_icons', json.encode(map));
    });
  }

  // Цвет авто-папок проектов (тег → индекс в ClarifyTokens.tagPalette) —
  // тем же способом, что и иконки: локально в Hive, без Supabase.
  Map<String, int> _readProjectColorKeys() {
    final raw = _settingsBox.get('project_colors');
    if (raw == null) return {};
    return Map<String, int>.from(json.decode(raw));
  }

  void _setProjectColor(String tag, int colorIndex) {
    setState(() {
      final map = _readProjectColorKeys();
      map[tag] = colorIndex;
      _settingsBox.put('project_colors', json.encode(map));
    });
  }

  Future<void> _setWorkspaceIcon(int workspaceId, String iconKey) async {
    setState(() {
      final idx = workspaces.indexWhere((w) => w['id'] == workspaceId);
      if (idx != -1) workspaces[idx]['icon'] = iconKey;
    });
    try {
      await Supabase.instance.client.from('workspaces').update({'icon': iconKey}).eq('id', workspaceId);
    } catch (e) {
      print("Не удалось сохранить иконку команды: $e");
    }
  }

  @override
  void dispose() {
    _taskService.dispose(); // <--- ЗАКРЫВАЕМ СОКЕТ ЧЕРЕЗ СЕРВИС
    _aiChatController.dispose();
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

  // "Ежедневный обзор" — утренняя сводка (сколько задач сегодня, сколько
  // просрочено), не поздравление с закрытием всех задач (как было раньше) —
  // та версия срабатывала только в узком случае "все задачи на сегодня
  // выполнены", из-за чего выглядела как "не работает" для большинства
  // пользователей. Показывается один раз за день, при первой загрузке задач
  // в этой сессии — не привязана к конкретному времени суток (у бэкенда нет
  // таймзоны пользователя, чтобы слать это именно утром через push).
  void _checkDailyReviewTrigger() {
    if (!AppSettings.dailyReviewEnabled) return;
    final todayStr = _formatDate(DateTime.now());
    if (_dailyReviewShownForDate == todayStr) return; // Уже показывали сегодня
    _dailyReviewShownForDate = todayStr;

    final todayPending = tasks.where((t) => t['due_date'] == todayStr && t['parent_id'] == null && t['is_completed'] != true).length;
    final overdueCount = tasks.where((t) => _isOverdue(t)).length;

    _showDailyReviewOverlay(todayCount: todayPending, overdueCount: overdueCount);
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
    if (!AppSettings.notificationsEnabled) return;

    if (kIsWeb) {
      // local_notifier не имеет веб-реализации (MissingPluginException) —
      // на web/PWA попап идёт через настоящий браузерный Notification API.
      if (!BrowserNotification.show(title, body)) {
        if (mounted) {
          ClarifyToast.show(context, "$title: $body", variant: ClarifyToastVariant.info);
        }
      }
      return;
    }

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
        ClarifyToast.show(context, "$title: $body", variant: ClarifyToastVariant.info);
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
    if (!_speechEnabled) { ClarifyToast.show(context, "Микрофон недоступен.", variant: ClarifyToastVariant.danger); return; }
    if (_speechToText.isListening) { await _speechToText.stop(); setState(() => _isListening = false); } 
    else { setState(() => _isListening = true); final currentText = _aiChatController.text; await _speechToText.listen(localeId: _currentLocaleId, onResult: (result) { setState(() { if (currentText.isEmpty) { _aiChatController.text = result.recognizedWords; } else { _aiChatController.text = "$currentText ${result.recognizedWords}"; } }); }); }
  }

  String _formatDate(DateTime d) => "${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}";
  DateTime? _parseDate(String dateStr) { try { final parts = dateStr.split('.'); if (parts.length == 3) return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0])); } catch (e) { return null; } return null; }

  // 'red'/'orange'/'blue'/'gray' — исторические имена цвета в БД, семантически urgent/important/normal/low.
  Color _getPriorityColor(String? priority) { switch (priority) { case 'red': return _tokens.danger; case 'orange': return _tokens.warning; case 'blue': return _tokens.accent; case 'gray': return textMuted; default: return borderStrong; } }

  List<Map<String, dynamic>> get filteredTasks {
    var result = tasks;
    if (activeTagFilter != null) {
      result = result.where((t) => parseTagsString(t['tags']).contains(activeTagFilter)).toList();
    }
    if (activePriorityFilter != null) {
      result = result.where((t) => t['priority'] == activePriorityFilter).toList();
    }
    return result;
  }
  Map<String, int> _getSubtaskStats(dynamic parentId) { final subtasks = tasks.where((t) => t['parent_id'] == parentId).toList(); if (subtasks.isEmpty) return {'total': 0, 'done': 0}; return {'total': subtasks.length, 'done': subtasks.where((t) => t['is_completed'] == true).length}; }

  Future<void> _fetchTasks() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final fetchedTasks = await _taskService.fetchTasks();
      if (mounted) {
        setState(() {
          // Пока для задачи есть незавершённое собственное действие (toggle
          // ещё летит на сервер, см. _pendingActionIds/_guardedAction) — не
          // даём этому fetchTasks() (например, случайно триггернутому чужим
          // realtime-событием, пришедшим прямо во время нашего же клика)
          // откатить локальное оптимистичное состояние снимком с сервера,
          // который мог быть сделан ДО того, как наш собственный запрос
          // закоммитился. Именно это было причиной периодического "мигания"
          // чекбокса (отметился/откатился/отметился).
          if (_pendingActionIds.isNotEmpty) {
            for (final fetched in fetchedTasks) {
              if (_pendingActionIds.contains('toggle_${fetched['id']}')) {
                final local = tasks.firstWhere((t) => t['id'] == fetched['id'], orElse: () => const {});
                if (local.isNotEmpty) fetched['is_completed'] = local['is_completed'];
              }
            }
          }
          tasks = fetchedTasks;
          _isOffline = false;
          _pendingOpsCount = _taskService.pendingOpsCount;
          _applyFilters();
          _rebuildAllAlarms();
        });
        _checkMissedDeadlinesOnStartup();
        _checkDailyReviewTrigger();
      }
    } catch (e) {
      print("!!! РЕАЛЬНАЯ ОШИБКА БАЗЫ ДАННЫХ: $e");
      if (mounted) {
        setState(() {
          _isOffline = true;
          _pendingOpsCount = _taskService.pendingOpsCount;
        });
        ClarifyToast.show(context, "Нет сети. Работаем локально!".tr(widget.currentLang), variant: ClarifyToastVariant.warning);
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

    // Костыль ниже — компромисс именно под Windows-.exe без MSIX (см.
    // комментарий выше). На web/PWA он не нужен и мешает: там уже есть
    // настоящий фоновый push через /internal/check-due-tasks, и без этой
    // проверки пользователь получал системное уведомление о просроченных
    // задачах при КАЖДОМ открытии приложения, а не только когда реально
    // пропустил дедлайн, пока оно было закрыто.
    if (kIsWeb) return;

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

  // Общая логика для десктопной AI-панели и мобильного AI-экрана —
  // POST /tasks/parse + подтягивание созданных задач. Бросает
  // AiParseHttpException на не-200 ответ, чтобы вызывающий код мог
  // показать разные сообщения для "сервер ответил ошибкой" и "нет связи".
  Future<int> _parseTextToTasks(String text) async {
    final accessToken = Supabase.instance.client.auth.currentSession?.accessToken;
    final response = await http.post(
      Uri.parse('$baseUrl/tasks/parse'),
      headers: {
        'Content-Type': 'application/json',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      },
      body: json.encode({'text': text}),
    );
    if (response.statusCode != 200) {
      throw AiParseHttpException(response.statusCode);
    }
    final List addedTasks = json.decode(response.body);
    await _fetchTasks();
    return addedTasks.length;
  }

  Future<void> _sendTaskToAI(String text) async {
    if (text.trim().isEmpty) return;
    setState(() { chatMessages.add({'role': 'user', 'text': text.trim()}); isAiTyping = true; }); _aiChatController.clear();
    try {
      final count = await _parseTextToTasks(text);
      setState(() { chatMessages.add({'role': 'ai', 'text': 'Готово! Добавлено задач: $count. '.tr(widget.currentLang)}); isAiTyping = false; });
    } on AiParseHttpException catch (e) {
      setState(() { chatMessages.add({'role': 'ai', 'text': 'Ошибка: сервер вернул ${e.statusCode}'}); isAiTyping = false; });
    } catch (e) {
      setState(() { chatMessages.add({'role': 'ai', 'text': 'Ошибка связи с ИИ.'.tr(widget.currentLang)}); isAiTyping = false; });
    }
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
      // addTask уже поставил создание в очередь на повтор (TaskService.flushPendingOps) —
      // сообщаем об этом пользователю, а не просто теряем ошибку молча (см. print ниже).
      print("Ошибка создания задачи: $e".tr(widget.currentLang));
      if (mounted) {
        setState(() => _pendingOpsCount = _taskService.pendingOpsCount);
        final message = e is PostgrestException
            ? "Не удалось сохранить: ".tr(widget.currentLang) + e.message
            : "Не удалось сохранить задачу на сервере. Отправим, когда сеть восстановится.".tr(widget.currentLang);
        ClarifyToast.show(context, message, variant: ClarifyToastVariant.warning);
      }
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
        final message = e is PostgrestException
            ? "Не удалось сохранить: ".tr(widget.currentLang) + e.message
            : "Нет сети. Изменение отправим, когда сеть восстановится.".tr(widget.currentLang);
        ClarifyToast.show(context, message, variant: ClarifyToastVariant.warning);
      }
    }
  }

  Future<void> _spawnNextRecurringTask(Map<String, dynamic> task) async {
    DateTime? oldDate = _parseDate(task['due_date']); if (oldDate == null) return;
    DateTime newDate = oldDate;
    if (task['recurrence'] == 'daily') {
      newDate = oldDate.add(const Duration(days: 1));
    } else if (task['recurrence'] == 'weekdays') {
      int addDays = 1;
      if (oldDate.weekday == DateTime.friday) {
        addDays = 3;
      } else if (oldDate.weekday == DateTime.saturday) {
        addDays = 2;
      }
      newDate = oldDate.add(Duration(days: addDays));
    } else if (task['recurrence'] == 'weekly') {
      newDate = oldDate.add(const Duration(days: 7));
    } else if (task['recurrence'] == 'monthly') {
      newDate = DateTime(oldDate.year, oldDate.month + 1, oldDate.day);
    } else if (task['recurrence'] == 'custom') {
      final interval = (task['recurrence_interval'] as int?) ?? 1;
      newDate = oldDate.add(Duration(days: interval));
    }
    int? newTaskId = await _createTaskManually({"title": task['title'], "due_date": _formatDate(newDate), "due_time": task['due_time'], "note": task['note'], "priority": task['priority'], "tags": task['tags'], "recurrence": task['recurrence'], "recurrence_interval": task['recurrence_interval'], "parent_id": task['parent_id'], "is_completed": false});
    if (newTaskId != null && task['parent_id'] == null) { final subtasks = tasks.where((t) => t['parent_id'] == task['id']).toList(); for (var sub in subtasks) { await _createTaskManually({"title": sub['title'], "parent_id": newTaskId, "is_completed": false}); } }
  }

  Future<void> _toggleTask(Map<String, dynamic> task) async {
    final actionId = 'toggle_${task['id']}';
    if (_pendingActionIds.contains(actionId)) return; // Уже в процессе — игнорируем повторный тап

    final bool currentStatus = task['is_completed'] == true;
    final bool newStatus = !currentStatus;
    final currentCompletedAt = task['completed_at'];
    final String? newCompletedAt = newStatus ? DateTime.now().toIso8601String() : null;

    setState(() {
      task['is_completed'] = newStatus;
      task['completed_at'] = newCompletedAt;
      _applyFilters();
    });

    await _guardedAction(actionId, () async {
      try {
        await _taskService.updateTask(task['id'], {'is_completed': newStatus, 'completed_at': newCompletedAt}); // <--- ИСПОЛЬЗУЕМ СЕРВИС

        if (newStatus == true && task['recurrence'] != null && task['recurrence'] != 'none') {
          _spawnNextRecurringTask(task);
        }

        // Раньше здесь был ещё и явный _fetchTasks() — но initRealtime уже
        // подписан на изменения таблицы tasks и сам вызывает _fetchTasks()
        // при коммите этого же UPDATE (onTasksChanged, см. ниже). Два
        // параллельных fetchTasks() на одно действие гонялись друг с другом
        // и оба целиком перезаписывали tasks новыми объектами — из-за этого
        // чекбокс визуально "отмечался, откатывался, отмечался снова" за
        // один клик. Оптимистичное обновление выше уже отражает верное
        // состояние — второй, серверный, придёт сам через realtime.

      } catch (e) {
        setState(() {
          task['is_completed'] = currentStatus;
          task['completed_at'] = currentCompletedAt;
          _applyFilters();
        });
        print("Ошибка обновления статуса: $e");
      }
    });
  }

  // Приветствие зависит от текущего часа — раньше всегда было "Доброе утро!"
  // независимо от времени суток, потому что показ этого оверлея не привязан
  // к конкретному часу (см. комментарий у _checkDailyReviewTrigger — у
  // бэкенда нет таймзоны пользователя для push именно утром).
  String _greetingForNow() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return "Доброе утро!";
    if (hour >= 12 && hour < 18) return "Добрый день!";
    if (hour >= 18 && hour < 23) return "Добрый вечер!";
    return "Доброй ночи!";
  }

  void _showDailyReviewOverlay({required int todayCount, required int overdueCount}) {
    final greeting = _greetingForNow();

    showClarifyResponsiveSurface(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (context) {
        final mobile = isClarifyDialogMobile(context);
        final iconSize = mobile ? 36.0 : 44.0 * _s;
        final titleSize = mobile ? 20.0 : 24.0 * _s;
        final bodySize = mobile ? 15.0 : 16.0 * _s;
        final overdueSize = mobile ? 14.0 : 15.0 * _s;

        final content = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.sunrise, size: iconSize, color: _tokens.accent),
            SizedBox(height: mobile ? 14 : 20 * _s),
            Text(greeting.tr(widget.currentLang), style: TextStyle(color: textColor, fontSize: titleSize, fontWeight: FontWeight.w800)),
            SizedBox(height: mobile ? 8 : 12 * _s),
            Text(
              todayCount == 0
                  ? "На сегодня задач не запланировано.".tr(widget.currentLang)
                  : "${'Сегодня у вас'.tr(widget.currentLang)} $todayCount ${'задач'.tr(widget.currentLang)}.",
              textAlign: TextAlign.center,
              style: TextStyle(color: textMuted, fontSize: bodySize, height: 1.4),
            ),
            if (overdueCount > 0) ...[
              SizedBox(height: mobile ? 8 : 10 * _s),
              Text(
                "${'Просрочено:'.tr(widget.currentLang)} $overdueCount",
                style: TextStyle(color: _tokens.danger, fontSize: overdueSize, fontWeight: FontWeight.w700),
              ),
            ],
            SizedBox(height: mobile ? 20 : 28 * _s),
            ClarifyButton(
              label: "Понятно".tr(widget.currentLang),
              variant: ClarifyButtonVariant.filled,
              scale: mobile ? 1.0 : _s,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        );

        // Мобильный — bottom sheet (showClarifyResponsiveSurface уже даёт
        // форму/ширину/drag-to-dismiss через showClarifyBottomSheet), десктоп
        // — прежняя плавающая карточка по центру. Раньше этот диалог был
        // одинаковым на обеих платформах — "плавающая карточка" на мобильном
        // выглядела как урезанный десктоп, а не как остальные мобильные шторки.
        if (mobile) {
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.of(context).padding.bottom + 20),
            child: content,
          );
        }
        return Center(
          child: Material(
            color: Colors.transparent,
            child: _buildGlassContainer(
              borderRadius: BorderRadius.circular(28 * _s),
              padding: EdgeInsets.all(32 * _s),
              child: SizedBox(
                width: (MediaQuery.sizeOf(context).width - 96).clamp(280.0, 420.0),
                child: content,
              ),
            ),
          ),
        );
      },
    );
  }

void _checkBurnoutWarning(String dateStr) {
    if (_burnoutWarnedDates.contains(dateStr)) return; // Уже предупреждали про этот день

    final dayTasks = tasks.where((t) => t['due_date'] == dateStr && t['parent_id'] == null).toList();

    if (dayTasks.length >= AppConfig.burnoutTaskThreshold) {
      _burnoutWarnedDates.add(dateStr);
      showClarifySurface(
        context: context,
        builder: (context) {
          return Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 380 * _s,
                padding: EdgeInsets.all(32 * _s),
                decoration: BoxDecoration(
                  color: _tokens.surface2,
                  borderRadius: BorderRadius.circular(24 * _s),
                  border: Border.all(color: _tokens.accent.withValues(alpha: 0.3), width: 2),
                  boxShadow: [
                    BoxShadow(color: _tokens.accent.withValues(alpha: 0.1), blurRadius: 20, spreadRadius: 5)
                  ]
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.flower, size: 60 * _s, color: _tokens.accent),
                    SizedBox(height: 20 * _s),
                    Text("Эй, притормози! 🛑".tr(widget.currentLang), style: TextStyle(color: textColor, fontSize: 24 * _s, fontWeight: FontWeight.w900)),
                    SizedBox(height: 12 * _s),
                    Text(
                      "Это уже 10-я задача на этот день.\n\nПродуктивность — это прекрасно, но выгорание нам ни к чему. Постарайся не перегружать расписание и обязательно оставляй окна для отдыха.\nТы не робот! 🤖", // <-- Текст тоже обновили
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textMuted, fontSize: 14 * _s, height: 1.5)
                    ),
                    SizedBox(height: 28 * _s),
                    ClarifyButton(
                      label: "Понял, спасибо".tr(widget.currentLang),
                      variant: ClarifyButtonVariant.filled,
                      scale: _s,
                      onPressed: () => Navigator.pop(context),
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
        final message = e is PostgrestException
            ? "Не удалось удалить: ".tr(widget.currentLang) + e.message
            : "Нет сети. Удаление отправим, когда сеть восстановится.".tr(widget.currentLang);
        ClarifyToast.show(context, message, variant: ClarifyToastVariant.warning);
      }
    }
  }
  
  void _applyFilters() {}

  void shiftDate(int days, int months, StateSetter setStateDialog, DateTime? currentDate) { DateTime baseDate = currentDate ?? DateTime.now(); setStateDialog(() => currentDate = DateTime(baseDate.year, baseDate.month + months, baseDate.day + days)); }

  void _showManualAddDialog({DateTime? preselectedDate, Map<String, dynamic>? sourceTaskForDuplicate, Offset? originOffset}) {
    showManualAddDialog(
      context: context,
      originOffset: originOffset,
      isDark: isDark,
      scale: _s,
      textColor: textColor,
      textMuted: textMuted,
      glassBorderColor: glassBorderColor,
      doneCardColor: doneCardColor,
      highlightColor: highlightColor,
      currentLang: widget.currentLang,
      selectedMenu: selectedMenu,
      activeTagFilter: activeTagFilter,
      tasks: tasks,
      workspaceMembers: workspaceMembers,
      isDuplicating: _isDuplicating,
      onDuplicateHandled: () => setState(() { _isDuplicating = false; _taskToDuplicate = null; }),
      createTaskManually: _createTaskManually,
      checkBurnoutWarning: _checkBurnoutWarning,
      parseSmartInput: _parseSmartInput,
      getPriorityColor: _getPriorityColor,
      formatDate: _formatDate,
      shiftDate: shiftDate,
      buildGlassContainer: _buildGlassContainer,
      preselectedDate: preselectedDate,
      sourceTaskForDuplicate: sourceTaskForDuplicate,
    );
  }

  void _showEditTaskDialog(Map<String, dynamic> task) {
    showEditTaskDialog(
      context: context,
      task: task,
      isDark: isDark,
      textColor: textColor,
      textMuted: textMuted,
      glassBorderColor: glassBorderColor,
      currentLang: widget.currentLang,
      tasks: tasks,
      workspaceMembers: workspaceMembers,
      updateTaskData: _updateTaskData,
      getPriorityColor: _getPriorityColor,
      formatDate: _formatDate,
      parseDate: _parseDate,
      buildGlassContainer: _buildGlassContainer,
    );
  }

  void _showTaskDetailsDialog(Map<String, dynamic> task) {
    showTaskDetailsDialog(
      context: context,
      task: task,
      isDark: isDark,
      textColor: textColor,
      textMuted: textMuted,
      glassColor: glassColor,
      glassBorderColor: glassBorderColor,
      cardColor: cardColor,
      doneCardColor: doneCardColor,
      highlightColor: highlightColor,
      currentLang: widget.currentLang,
      tasks: tasks,
      workspaceMembers: workspaceMembers,
      getPriorityColor: _getPriorityColor,
      onToggleTask: _toggleTask,
      onDeleteTask: _deleteTask,
      onTagTap: (tag) => setState(() => activeTagFilter = tag),
      onDuplicate: (task) {
        // На мобильном — сразу открываем окно добавления с предзаполненными
        // данными, без промежуточного "нажми на плюсик любого дня" (см. кнопку
        // "Дублировать" в task_details_dialog.dart). Десктоп — как раньше,
        // выбор конкретного дня кликом по его "+".
        if (isClarifyDialogMobile(context)) {
          _showManualAddDialog(sourceTaskForDuplicate: task, preselectedDate: DateTime.now());
        } else {
          setState(() { _taskToDuplicate = task; _isDuplicating = true; });
        }
      },
      onEdit: _showEditTaskDialog,
      buildGlassContainer: _buildGlassContainer,
    );
  }

  void _handlePlusTap(DateTime date, int currentDayTaskCount) {
    if (currentDayTaskCount >= AppConfig.dailyTaskLimit) { ClarifyToast.show(context, "Лимит задач (100) исчерпан!".tr(widget.currentLang), variant: ClarifyToastVariant.danger); return; }
    if (_isDuplicating && _taskToDuplicate != null) { _showManualAddDialog(preselectedDate: date, sourceTaskForDuplicate: _taskToDuplicate); } 
    else { _showManualAddDialog(preselectedDate: date); }
  }

  void _handleTaskTap(Map<String, dynamic> task) { _showTaskDetailsDialog(task); }

  void _handleTaskDropped({required Map<String, dynamic> task, required String targetDateStr, required int currentTargetTaskCount}) async {
    final actionId = 'drop_${task['id']}';
    if (_pendingActionIds.contains(actionId)) return; // Уже переносится — игнорируем повторный дроп

    await _guardedAction(actionId, () async {
      await _fetchTasks();
      _checkBurnoutWarning(targetDateStr);
      if (currentTargetTaskCount >= AppConfig.dailyTaskLimit) { ClarifyToast.show(context, "Лимит 100 задач!".tr(widget.currentLang), variant: ClarifyToastVariant.danger); return; }
      if (HardwareKeyboard.instance.isControlPressed) {
        int? newTaskId = await _createTaskManually({"title": task['title'], "due_date": targetDateStr, "due_time": task['due_time'], "note": task['note'], "priority": task['priority'], "tags": task['tags'], "recurrence": task['recurrence'], "recurrence_interval": task['recurrence_interval'], "parent_id": task['parent_id'], "is_completed": false});
        if (newTaskId != null && task['parent_id'] == null) {
          final subtasksToCopy = tasks.where((t) => t['parent_id'] == task['id']).toList();
          for (var sub in subtasksToCopy) { await _createTaskManually({"title": sub['title'], "parent_id": newTaskId, "is_completed": false}); }
        }
        if (mounted) ClarifyToast.show(context, "Скопировано!".tr(widget.currentLang), variant: ClarifyToastVariant.success);
      } else {
        // Перенос вперёд перетаскиванием на невыполненной задаче тоже считается переносом (см. AppConfig.rescheduleWarningCount) — это самый "невидимый" случай, задачу двигают одним жестом не задумываясь.
        if (task['due_date'] != targetDateStr) {
          int newRescheduleCount = (task['reschedule_count'] as int?) ?? 0;
          if (task['is_completed'] != true && task['due_date'] != null) {
            final oldDate = _parseDate(task['due_date']);
            final newDate = _parseDate(targetDateStr);
            if (oldDate != null && newDate != null && newDate.isAfter(oldDate)) { newRescheduleCount += 1; }
          }
          // await обязателен: _guardedAction держит actionId "занятым" до
          // завершения этого колбэка (см. _guardedAction выше) — раньше здесь
          // не было await, поэтому колбэк резолвился сразу же, не дожидаясь
          // реального обновления+рефетча, и повторный дроп той же задачи
          // почти сразу успевал прочитать ЕЩЁ старое reschedule_count из
          // локального `task` — несколько быстрых переносов подряд считались
          // как один и тот же +1 вместо накопления.
          await _updateTaskData(task['id'], {"title": task['title'], "due_date": targetDateStr, "due_time": task['due_time'], "note": task['note'], "priority": task['priority'], "tags": task['tags'], "recurrence": task['recurrence'], "recurrence_interval": task['recurrence_interval'], "parent_id": task['parent_id'], "is_completed": task['is_completed'] ?? false, "reschedule_count": newRescheduleCount});
        }
      }
    });
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

    // Мобильная/PWA-раскладка — отдельно спроектированная навигация, не десктопный
    // сайдбар, сжатый в узкий экран (см. docs/DESIGN_SYSTEM.md, "один проход стройки").
    if (screenWidth < 700) {
      return MobilePlannerShell(
        currentLang: widget.currentLang,
        userInitial: _userInitial,
        userFullName: _userFullName,
        tasks: tasks,
        workspaces: workspaces,
        workspaceMembers: workspaceMembers,
        formatDate: _formatDate,
        getPriorityColor: _getPriorityColor,
        getSubtaskStats: _getSubtaskStats,
        isOverdue: _isOverdue,
        onToggleTask: _toggleTask,
        onDeleteTask: _deleteTask,
        onTaskTap: _handleTaskTap,
        onQuickUpdateTask: _updateTaskData,
        onAddTask: ({DateTime? preselectedDate}) => _showManualAddDialog(preselectedDate: preselectedDate),
        createTaskManually: _createTaskManually,
        onAiParseText: _parseTextToTasks,
        checkBurnoutWarning: _checkBurnoutWarning,
        onOpenWorkspaceMembers: _fetchWorkspaceMembers,
        onInviteToWorkspace: (wsId) => showInviteMemberDialog(
          context: context,
          workspaceId: wsId,
          isDark: isDark,
          scale: 1.0,
          textColor: textColor,
          textMuted: textMuted,
          glassBorderColor: glassBorderColor,
          currentLang: widget.currentLang,
        ),
        onLeaveOrDeleteWorkspace: _showLeaveOrDeleteWorkspace,
        onShowTeamPulse: (wsId) => showTeamPulseDialog(
          context: context,
          wsId: wsId,
          scale: 1.0,
          currentLang: widget.currentLang,
          textColor: textColor,
          textMuted: textMuted,
          tasks: tasks,
          workspaceMembers: workspaceMembers,
          formatDate: _formatDate,
          buildGlassContainer: _buildGlassContainer,
        ),
        onAddWorkspace: () => showCreateWorkspaceDialog(
          context: context,
          isDark: isDark,
          scale: 1.0,
          textColor: textColor,
          textMuted: textMuted,
          glassBorderColor: glassBorderColor,
          currentLang: widget.currentLang,
          onWorkspaceCreated: _fetchWorkspaces,
        ),
        onOpenAccountSettings: _showAccountSettingsDialog,
        buildStatisticsDashboard: _buildStatisticsDashboardWidget,
        isDark: isDark,
        toggleTheme: widget.toggleTheme,
        changeLang: widget.changeLang,
      );
    }

    return AmbientBackground(
      isDark: isDark,
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
                      workspaces: workspaces,
                      onSetWorkspaceIcon: _setWorkspaceIcon,
                      onMenuSelected: (menu) => setState(() => selectedMenu = menu),
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
                      userAccountBlockCollapsed: _buildUserAccountBlockCollapsed(),
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
                                  style: TextStyle(fontSize: 32 * _s, fontWeight: FontWeight.w700, letterSpacing: -1.0, color: textColor)
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
                                                child: GestureDetector(
                                                  onTap: () => showUserProfileModal(
                                                    context: context,
                                                    userId: m['user_id'].toString(),
                                                    currentLang: widget.currentLang,
                                                    teamRole: m['role']?.toString(),
                                                    onOpenOwnSettings: _showAccountSettingsDialog,
                                                    onOpenConversation: (userId, name) => setState(() {
                                                      _pendingChatPartnerId = userId;
                                                      _pendingChatPartnerName = name;
                                                      selectedMenu = 'Сообщения';
                                                    }),
                                                  ),
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
                                                          Icon(LucideIcons.flower, color: Colors.white.withOpacity(0.9), size: 20 * _s),
                                                          
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
                                        child: ClarifyButton(
                                          variant: ClarifyButtonVariant.outline,
                                          scale: _s,
                                          icon: LucideIcons.userPlus,
                                          label: "Пригласить".tr(widget.currentLang),
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
                                      Padding(
                                        padding: EdgeInsets.only(right: 16 * _s),
                                        child: ClarifyIconButton(
                                          icon: LucideIcons.logOut,
                                          scale: _s,
                                          tooltip: "Покинуть/удалить команду".tr(widget.currentLang),
                                          onPressed: () => _showLeaveOrDeleteWorkspace(int.parse(selectedMenu.substring(3))),
                                        ),
                                      ),
                                    ],

                                    if (_isOffline)
                                      Padding(
                                        padding: EdgeInsets.only(right: 12 * _s),
                                        child: Icon(LucideIcons.cloudOff, color: _tokens.warning, size: 24 * _s),
                                      ),

                                    if (_pendingOpsCount > 0)
                                      Padding(
                                        padding: EdgeInsets.only(right: 12 * _s),
                                        child: Tooltip(
                                          message: "${'Несинхронизированных изменений: '.tr(widget.currentLang)}$_pendingOpsCount",
                                          child: Icon(LucideIcons.cloudAlert, color: _tokens.warning, size: 24 * _s),
                                        ),
                                      ),


                                    // Фокус-режим — filled только пока активен, один и тот же акцент, что и везде
                                    ClarifyButton(
                                      variant: _isMyZenActive ? ClarifyButtonVariant.filled : ClarifyButtonVariant.outline,
                                      scale: _s,
                                      icon: LucideIcons.flower,
                                      label: _isMyZenActive ? "В фокусе".tr(widget.currentLang) : "Фокусирование".tr(widget.currentLang),
                                      onPressed: _toggleZenMode,
                                    ),
                                    SizedBox(width: 12 * _s),
                                    // Пульс команды (только внутри воркспейса) — нейтральная иконка, не тревожный красный
                                    if (selectedMenu.startsWith('ws_')) ...[
                                      ClarifyIconButton(
                                        icon: LucideIcons.heartPulse,
                                        scale: _s,
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
                                    ClarifyIconButton(icon: LucideIcons.refreshCw, scale: _s, onPressed: _fetchTasks),
                                    SizedBox(width: 4 * _s),
                                    ClarifyIconButton(
                                      icon: isDark ? LucideIcons.sun : LucideIcons.moon,
                                      scale: _s,
                                      onPressed: widget.toggleTheme,
                                    ),
                                    SizedBox(width: 16 * _s),
                                    ClarifyButton(
                                      variant: rightPanelState == 'ai' ? ClarifyButtonVariant.outline : ClarifyButtonVariant.filled,
                                      scale: _s,
                                      icon: rightPanelState == 'ai' ? LucideIcons.x : LucideIcons.sparkles,
                                      label: rightPanelState == 'ai' ? "Закрыть чат".tr(widget.currentLang) : "AI Ассистент".tr(widget.currentLang),
                                      onPressed: () => setState(() => rightPanelState = rightPanelState == 'ai' ? 'none' : 'ai'),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                          if (activeTagFilter != null || activePriorityFilter != null)
                            Padding(
                              padding: EdgeInsets.fromLTRB(40 * _s, 0, 40 * _s, 24 * _s),
                              child: Row(
                                children: [
                                  if (activeTagFilter != null) ...[
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 16 * _s, vertical: 8 * _s), decoration: BoxDecoration(color: highlightColor, borderRadius: BorderRadius.circular(ClarifyRadius.pill), border: Border.all(color: _tokens.accent.withValues(alpha: 0.4))),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(LucideIcons.funnel, size: 18 * _s, color: _tokens.accent), SizedBox(width: 8 * _s),
                                          Text("${'Тег: '.tr(widget.currentLang)}#$activeTagFilter", style: TextStyle(color: _tokens.accent, fontWeight: FontWeight.bold, fontSize: 15 * _s)), SizedBox(width: 12 * _s),
                                          InkWell(onTap: () => setState(() => activeTagFilter = null), child: Container(padding: EdgeInsets.all(4 * _s), decoration: BoxDecoration(shape: BoxShape.circle, color: _tokens.accent.withValues(alpha: 0.6)), child: Icon(LucideIcons.x, size: 14 * _s, color: _tokens.onAccent),))
                                        ],
                                      )
                                    ),
                                    SizedBox(width: 12 * _s),
                                  ],
                                  if (activePriorityFilter != null)
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 16 * _s, vertical: 8 * _s), decoration: BoxDecoration(color: highlightColor, borderRadius: BorderRadius.circular(ClarifyRadius.pill), border: Border.all(color: _getPriorityColor(activePriorityFilter).withValues(alpha: 0.4))),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(LucideIcons.flag, size: 18 * _s, color: _getPriorityColor(activePriorityFilter)), SizedBox(width: 8 * _s),
                                          Text("${'Приоритет: '.tr(widget.currentLang)}${priorityFlagLabel(activePriorityFilter)}", style: TextStyle(color: _getPriorityColor(activePriorityFilter), fontWeight: FontWeight.bold, fontSize: 15 * _s)), SizedBox(width: 12 * _s),
                                          InkWell(onTap: () => setState(() => activePriorityFilter = null), child: Container(padding: EdgeInsets.all(4 * _s), decoration: BoxDecoration(shape: BoxShape.circle, color: _getPriorityColor(activePriorityFilter).withValues(alpha: 0.6)), child: Icon(LucideIcons.x, size: 14 * _s, color: _tokens.onAccent),))
                                        ],
                                      )
                                    ),
                                ],
                              )
                            ),
                          // Переходим к главному контенту (Через вынесенный виджет).
                          // SharedAxisTransition при смене пункта сайдбара — сдержанный
                          // переход вместо мгновенной смены (REDESIGN_V3_PLAN.md §3.6/5.6).
                          Expanded(
                            child: PageTransitionSwitcher(
                              duration: ClarifyMotion.slow,
                              // Дефолтный layoutBuilder пакета animations кладёт
                              // страницы в Stack(alignment: Alignment.center) —
                              // контент короче доступной высоты (как в
                              // "Статистике", в отличие от списков, которые
                              // всегда заполняют Expanded целиком) оказывался
                              // отцентрирован по вертикали, а не прижат к верху:
                              // отсюда "начинается не с самого верха". fit:expand
                              // заставляет каждую страницу занимать ровно всю
                              // высоту Expanded, alignment: topLeft — на случай,
                              // если что-то всё же не растянется на всю высоту.
                              layoutBuilder: (entries) => Stack(alignment: Alignment.topLeft, fit: StackFit.expand, children: entries),
                              transitionBuilder: (child, primaryAnimation, secondaryAnimation) => SharedAxisTransition(
                                animation: primaryAnimation,
                                secondaryAnimation: secondaryAnimation,
                                transitionType: SharedAxisTransitionType.horizontal,
                                child: child,
                              ),
                              child: KeyedSubtree(
                                key: ValueKey(selectedMenu),
                                child: Builder(builder: (context) {
                              final taskCardBuilders = TaskCardBuilders(
                                isDark: widget.isDark,
                                scale: _s,
                                currentLang: widget.currentLang,
                                workspaceMembers: workspaceMembers,
                                getPriorityColor: _getPriorityColor,
                                getSubtaskStats: _getSubtaskStats,
                                isOverdue: _isOverdue,
                                onToggle: _toggleTask,
                                onDelete: _deleteTask,
                                onTap: _handleTaskTap,
                                onTagTap: (tag) => setState(() => activeTagFilter = tag),
                                onPriorityTap: (priority) => setState(() => activePriorityFilter = priority),
                                onQuickUpdateTask: _updateTaskData,
                                buildGlassContainer: _buildGlassContainer,
                              );
                              return MainContentArea(
                              selectedMenu: selectedMenu,
                              currentLang: widget.currentLang,
                              filteredTasks: filteredTasks,
                              isDark: widget.isDark,
                              scale: _s,
                              onMenuSelected: (menu) => setState(() => selectedMenu = menu),
                              projectIconKeys: _readProjectIconKeys(),
                              onSetProjectIcon: _setProjectIcon,
                              projectColorKeys: _readProjectColorKeys(),
                              onSetProjectColor: _setProjectColor,
                              sortByPriority: sortByPriority,
                              onToggleSortByPriority: () => setState(() => sortByPriority = !sortByPriority),
                              pendingChatPartnerId: _pendingChatPartnerId,
                              pendingChatPartnerName: _pendingChatPartnerName,
                              onOpenDirectChat: (partnerId, name) => setState(() {
                                _pendingChatPartnerId = partnerId;
                                _pendingChatPartnerName = name;
                                selectedMenu = 'Сообщения';
                              }),
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
                              getLocalKanbanStatus: _getLocalKanbanStatus,
                              onSetLocalKanbanStatus: _setLocalKanbanStatus,
                              buildStatisticsDashboard: () => StatisticsDashboard(
                                tasks: tasks,
                                workspaces: workspaces,
                                currentLang: widget.currentLang,
                                textColor: textColor,
                                textMuted: textMuted,
                                isOverdue: _isOverdue,
                                parseDate: _parseDate,
                                getPriorityColor: _getPriorityColor,
                                buildGlassContainer: _buildGlassContainer,
                              ),
                              );
                            }),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ClipRect(
                      child: AnimatedContainer(
                        duration: ClarifyMotion.slow, curve: ClarifyMotion.spring, width: rightPanelState != 'none' ? 360 * _s : 0,
                        child: OverflowBox(
                          alignment: Alignment.centerRight,
                          minWidth: 360 * _s, maxWidth: 360 * _s,
                          child: AnimatedOpacity(
                            duration: ClarifyMotion.base, curve: ClarifyMotion.standard,
                            opacity: rightPanelState != 'none' ? 1 : 0,
                            child: _buildGlassContainer(
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
                        ),
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
          // Container transform через Hero откачен — "A Hero widget cannot be the
          // descendant of another Hero widget" при реальном запуске (не смог
          // безопасно продиагностировать вслепую без браузера/живой отладки).
          // Тот же эффект "окно вылетает из кнопки" сделан через
          // showClarifySurface() — точка клика ловится глобально
          // (LastTapTracker, main.dart), отдельно координаты FAB не нужны.
          child: FloatingActionButton.extended(
            onPressed: () { if (_isDuplicating && _taskToDuplicate != null) { _showManualAddDialog(preselectedDate: DateTime.now(), sourceTaskForDuplicate: _taskToDuplicate); } else { _showManualAddDialog(); } },
            // Тот же акцент, что у кнопки "AI Ассистент" (ClarifyButtonVariant.filled)
            // — раньше FAB был захардкожен на стоковый Colors.blueAccent, из-за чего
            // две акцентные кнопки в интерфейсе визуально спорили друг с другом.
            backgroundColor: _tokens.accent, foregroundColor: _tokens.onAccent, elevation: 8, icon: Icon(LucideIcons.plus, size: 26 * _s), label: Text("Создать задачу".tr(widget.currentLang), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16 * _s)),
          ),
        ),
      ),
    );
  }

  void _showLeaveOrDeleteWorkspace(int wsId) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final ws = workspaces.firstWhere((w) => w['id'] == wsId, orElse: () => {});
    final isOwner = ws['owner_id'] == currentUserId;
    final members = workspaceMembers[wsId] ?? [];
    final myMember = members.firstWhere((m) => m['user_id'] == currentUserId, orElse: () => {});
    final isAdmin = myMember['role'] == 'admin';

    showLeaveOrDeleteWorkspaceDialog(
      context: context,
      workspaceId: wsId,
      canDelete: isOwner || isAdmin,
      textColor: textColor,
      textMuted: textMuted,
      currentLang: widget.currentLang,
      onDone: () async {
        setState(() => selectedMenu = 'Мой день');
        await _fetchWorkspaces();
      },
    );
  }

  void _showAccountSettingsDialog() {
    showAccountSettingsDialog(
      context: context,
      isDark: isDark,
      textColor: textColor,
      textMuted: textMuted,
      glassColor: glassColor,
      glassBorderColor: glassBorderColor,
      highlightColor: highlightColor,
      currentLang: widget.currentLang,
      changeLang: widget.changeLang,
      onProfileChanged: () => setState(() {}),
      isMobileContext: MediaQuery.of(context).size.width < ClarifyBreakpoints.mobile,
      buildGlassContainer: _buildGlassContainer,
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
