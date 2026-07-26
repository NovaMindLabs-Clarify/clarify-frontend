import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/localization.dart';
import '../core/theme/design_tokens.dart';
import 'clarify_surface.dart';
import 'clarify_text_field.dart';

/// Session-scoped MRU для "Недавние" в командной палитре (REDESIGN_V4_PLAN.md
/// §6.6) — сбрасывается при перезапуске приложения; отдельного персистентного
/// хранилища для этого в проекте нет, заводить его здесь — за рамками задачи
/// (см. "Не входит" в плане).
final List<String> _paletteRecentKeys = [];

void _pushPaletteRecent(String key) {
  _paletteRecentKeys.remove(key);
  _paletteRecentKeys.insert(0, key);
  if (_paletteRecentKeys.length > 5) {
    _paletteRecentKeys.removeRange(5, _paletteRecentKeys.length);
  }
}

// Те же соответствия, что и в SidebarMenu._menuIcons (там — private,
// дублируем локально вместо расширения публичного API того файла ради
// одного нового потребителя).
const Map<String, IconData> _paletteNavIcons = {
  'Мой день': LucideIcons.sun,
  'Следующие 7 дней': LucideIcons.calendarDays,
  'Все задачи': LucideIcons.listChecks,
  'Календарь': LucideIcons.calendar,
  'Входящие': LucideIcons.inbox,
  'Проекты': LucideIcons.folderKanban,
  'Друзья': LucideIcons.userRound,
  'Сообщения': LucideIcons.messageCircle,
  'Статистика': LucideIcons.chartNoAxesColumn,
};

class _PaletteEntry {
  final String key;
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onSelect;

  const _PaletteEntry({
    required this.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onSelect,
  });
}

_PaletteEntry? _findByKey(List<_PaletteEntry> entries, String key) {
  for (final entry in entries) {
    if (entry.key == key) return entry;
  }
  return null;
}

/// Командная палитра (Ctrl+K, REDESIGN_V4_PLAN.md §6.6) — навигация, быстрые
/// действия и поиск задач в одном месте. Архитектурно по мотивам AppFlowy
/// command_palette.dart (см. план §6.6): 4 состояния (пустой запрос →
/// недавние + быстрые действия; есть совпадения → список; нет совпадений →
/// подсказка спросить AI; идёт поиск → индикатор) — но собственная реализация
/// на ClarifySurface/переданном buildGlassContainer, не портирование кода.
/// Только десктоп: на мобильном нет физической клавиатуры для Ctrl+K, а точка
/// входа туда намеренно не проектировалась в этом раунде (см. план).
void showCommandPalette({
  required BuildContext context,
  required String currentLang,
  required Color textColor,
  required Color textMuted,
  required bool isDark,
  required List<Map<String, dynamic>> tasks,
  required List<String> menuItems,
  required void Function(String menu) onNavigate,
  required VoidCallback onCreateTask,
  required VoidCallback onToggleTheme,
  required VoidCallback onOpenSettings,
  required void Function(String query) onAskAi,
  required void Function(Map<String, dynamic> task) onTaskSelected,
  required Widget Function({
    required Widget child,
    BorderRadius? borderRadius,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    Color? customColor,
  }) buildGlassContainer,
}) {
  showClarifySurface(
    context: context,
    barrierColor: Colors.black.withOpacity(0.6),
    builder: (context) {
      return _CommandPalette(
        currentLang: currentLang,
        textColor: textColor,
        textMuted: textMuted,
        isDark: isDark,
        tasks: tasks,
        menuItems: menuItems,
        onNavigate: onNavigate,
        onCreateTask: onCreateTask,
        onToggleTheme: onToggleTheme,
        onOpenSettings: onOpenSettings,
        onAskAi: onAskAi,
        onTaskSelected: onTaskSelected,
        buildGlassContainer: buildGlassContainer,
      );
    },
  );
}

class _CommandPalette extends StatefulWidget {
  final String currentLang;
  final Color textColor;
  final Color textMuted;
  final bool isDark;
  final List<Map<String, dynamic>> tasks;
  final List<String> menuItems;
  final void Function(String menu) onNavigate;
  final VoidCallback onCreateTask;
  final VoidCallback onToggleTheme;
  final VoidCallback onOpenSettings;
  final void Function(String query) onAskAi;
  final void Function(Map<String, dynamic> task) onTaskSelected;
  final Widget Function({
    required Widget child,
    BorderRadius? borderRadius,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    Color? customColor,
  }) buildGlassContainer;

  const _CommandPalette({
    required this.currentLang,
    required this.textColor,
    required this.textMuted,
    required this.isDark,
    required this.tasks,
    required this.menuItems,
    required this.onNavigate,
    required this.onCreateTask,
    required this.onToggleTheme,
    required this.onOpenSettings,
    required this.onAskAi,
    required this.onTaskSelected,
    required this.buildGlassContainer,
  });

  @override
  State<_CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<_CommandPalette> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';
  String _debouncedQuery = '';
  Timer? _debounce;
  int _highlightIndex = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _handleChanged(String value) {
    setState(() {
      _query = value;
      _highlightIndex = 0;
    });
    _debounce?.cancel();
    if (value.isEmpty) {
      setState(() => _debouncedQuery = '');
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      setState(() => _debouncedQuery = value);
    });
  }

  List<_PaletteEntry> _quickActions() {
    final lang = widget.currentLang;
    return [
      _PaletteEntry(
        key: 'action:createTask',
        icon: LucideIcons.plus,
        title: "Создать задачу".tr(lang),
        onSelect: widget.onCreateTask,
      ),
      for (final menu in widget.menuItems)
        _PaletteEntry(
          key: 'nav:$menu',
          icon: _paletteNavIcons[menu] ?? LucideIcons.circle,
          title: menu.tr(lang),
          onSelect: () => widget.onNavigate(menu),
        ),
      _PaletteEntry(
        key: 'action:settings',
        icon: LucideIcons.settings,
        title: "Настройки".tr(lang),
        onSelect: widget.onOpenSettings,
      ),
      _PaletteEntry(
        key: 'action:toggleTheme',
        icon: widget.isDark ? LucideIcons.sun : LucideIcons.moon,
        title: (widget.isDark ? "Светлая тема" : "Тёмная тема").tr(lang),
        onSelect: widget.onToggleTheme,
      ),
    ];
  }

  List<_PaletteEntry> _taskEntries(String query) {
    final lower = query.toLowerCase();
    return widget.tasks.where((task) {
      if (lower.isEmpty) return true;
      final title = task['title']?.toString().toLowerCase() ?? '';
      final note = task['note']?.toString().toLowerCase() ?? '';
      return title.contains(lower) || note.contains(lower);
    }).map((task) {
      final isDone = task['is_completed'] == true;
      return _PaletteEntry(
        key: 'task:${task['id']}',
        icon: isDone ? LucideIcons.checkCircle : LucideIcons.circle,
        title: (task['title'] ?? '').toString(),
        subtitle: task['note']?.toString(),
        onSelect: () => widget.onTaskSelected(task),
      );
    }).toList();
  }

  void _activate(_PaletteEntry entry) {
    if (!entry.key.startsWith('suggestion:')) {
      _pushPaletteRecent(entry.key);
    }
    Navigator.pop(context);
    entry.onSelect();
  }

  KeyEventResult _handleKey(KeyEvent event, List<_PaletteEntry> visible) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.pop(context);
      return KeyEventResult.handled;
    }
    if (visible.isEmpty) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() => _highlightIndex = (_highlightIndex + 1) % visible.length);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() => _highlightIndex = (_highlightIndex - 1 + visible.length) % visible.length);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _sectionHeader(String title, ClarifyTokens t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Text(
        title,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: widget.textMuted, letterSpacing: 0.4),
      ),
    );
  }

  Widget _entryTile(_PaletteEntry entry, bool highlighted, ClarifyTokens t) {
    return Material(
      color: highlighted ? t.accent.withOpacity(0.12) : Colors.transparent,
      borderRadius: BorderRadius.circular(ClarifyRadius.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(ClarifyRadius.sm),
        onTap: () => _activate(entry),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(entry.icon, size: 18, color: highlighted ? t.accent : widget.textMuted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: widget.textColor, fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    if (entry.subtitle != null && entry.subtitle!.isNotEmpty)
                      Text(
                        entry.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: widget.textMuted, fontSize: 12),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final lang = widget.currentLang;
    final quickActions = _quickActions();
    final isEmptyQuery = _query.isEmpty;
    final isLoading = !isEmptyQuery && _query != _debouncedQuery;

    List<_PaletteEntry> visible;
    Widget resultsChild;

    if (isEmptyQuery) {
      final allEntries = [...quickActions, ..._taskEntries('')];
      final recentEntries = _paletteRecentKeys
          .map((key) => _findByKey(allEntries, key))
          .whereType<_PaletteEntry>()
          .toList();
      visible = [...recentEntries, ...quickActions];
      final rows = <Widget>[
        if (recentEntries.isNotEmpty) ...[
          _sectionHeader("Недавние".tr(lang), t),
          for (final entry in recentEntries) _entryTile(entry, visible.indexOf(entry) == _highlightIndex, t),
        ],
        _sectionHeader("Быстрые действия".tr(lang), t),
        for (final entry in quickActions) _entryTile(entry, visible.indexOf(entry) == _highlightIndex, t),
      ];
      resultsChild = ListView(shrinkWrap: true, padding: EdgeInsets.zero, children: rows);
    } else if (isLoading) {
      visible = const [];
      resultsChild = Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: t.accent),
          ),
        ),
      );
    } else {
      final matches = [
        ...quickActions.where((a) => a.title.toLowerCase().contains(_debouncedQuery.toLowerCase())),
        ..._taskEntries(_debouncedQuery),
      ];
      if (matches.isEmpty) {
        final askEntry = _PaletteEntry(
          key: 'suggestion:askAi',
          icon: LucideIcons.sparkles,
          title: '${"Спросить AI".tr(lang)}: "$_debouncedQuery"',
          onSelect: () => widget.onAskAi(_debouncedQuery),
        );
        visible = [askEntry];
        resultsChild = ListView(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text("Ничего не найдено".tr(lang), style: TextStyle(color: widget.textMuted)),
            ),
            _entryTile(askEntry, 0 == _highlightIndex, t),
          ],
        );
      } else {
        visible = matches;
        resultsChild = ListView(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          children: [for (final entry in matches) _entryTile(entry, visible.indexOf(entry) == _highlightIndex, t)],
        );
      }
    }

    if (visible.isNotEmpty) {
      _highlightIndex = _highlightIndex.clamp(0, visible.length - 1);
    }
    final effectiveIndex = visible.isEmpty ? -1 : _highlightIndex;

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 100),
        child: Focus(
          onKeyEvent: (node, event) => _handleKey(event, visible),
          child: Material(
            color: Colors.transparent,
            child: SizedBox(
              width: 620,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  widget.buildGlassContainer(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: ClarifyTextField(
                      controller: _controller,
                      autofocus: true,
                      style: TextStyle(color: widget.textColor, fontSize: 18),
                      hintText: "Команда, раздел или задача...".tr(lang),
                      prefixIcon: Icon(LucideIcons.search, color: t.accent, size: 24),
                      onChanged: _handleChanged,
                      onSubmitted: (_) {
                        if (effectiveIndex >= 0) _activate(visible[effectiveIndex]);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  widget.buildGlassContainer(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 380),
                      child: resultsChild,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
