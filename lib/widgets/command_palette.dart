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

/// Нечёткое совпадение (subsequence-match, как в Sublime Text/VS Code) —
/// раньше поиск был строгим `.contains()`, любая опечатка или сокращение
/// («крч тск» не находит «Создать задачу») давали пустой результат (см.
/// docs/COMPETITOR_ANALYSIS_UPDATE_2026-07-31.md §2, пункт 3). Символы query
/// должны встретиться в text по порядку, не обязательно подряд.
/// Публичная (не `_`-приватная) — переиспользуется мобильным поиском
/// (mobile_search_screen.dart), у которого нет ни клавиатурной палитры, ни
/// самого доступа к private-функциям этого файла.
bool fuzzyMatches(String text, String query) {
  if (query.isEmpty) return true;
  final lowerText = text.toLowerCase();
  final lowerQuery = query.toLowerCase();
  var qi = 0;
  for (var ti = 0; ti < lowerText.length && qi < lowerQuery.length; ti++) {
    if (lowerText[ti] == lowerQuery[qi]) qi++;
  }
  return qi == lowerQuery.length;
}

/// Ниже — релевантнее (для сортировки по возрастанию): точное вхождение
/// подстроки побеждает любой нечёткий матч, и чем раньше оно встречается,
/// тем выше результат.
int fuzzyScore(String text, String query) {
  final index = text.toLowerCase().indexOf(query.toLowerCase());
  return index >= 0 ? index : 1 << 20;
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
  })
  buildGlassContainer,
}) {
  showClarifySurface(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.6),
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
  })
  buildGlassContainer;

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
  List<GlobalKey> _itemKeys = [];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // Клавиатурная подсветка и мышь раньше жили отдельно друг от друга —
  // наведение мышью никак не двигало _highlightIndex, в отличие от
  // Linear/Raycast/VS Code, где это работает в обе стороны (см.
  // docs/COMPETITOR_ANALYSIS_UPDATE_2026-07-31.md §2, пункт 1).
  void _ensureItemKeys(int count) {
    if (_itemKeys.length != count) {
      _itemKeys = List.generate(count, (_) => GlobalKey());
    }
  }

  void _setHighlight(int index) {
    if (index == _highlightIndex) return;
    setState(() => _highlightIndex = index);
  }

  // Без этого стрелки могли увести подсветку за пределы видимой области
  // ConstrainedBox(maxHeight: 380) без прокрутки списка вслед — известный
  // сбой, который Linear/Raycast явно решают (см. тот же §2, пункт 2).
  void _scrollToHighlight() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _highlightIndex < 0 ||
          _highlightIndex >= _itemKeys.length) {
        return;
      }
      final ctx = _itemKeys[_highlightIndex].currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: ClarifyMotion.fast,
          alignment: 0.5,
        );
      }
    });
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
    // Дебаунс ввода, а не анимация: токены движения сюда не подходят,
    // хотя число совпадает с ClarifyMotion.fast случайно.
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
    var tasks = widget.tasks;
    if (query.isNotEmpty) {
      tasks =
          tasks.where((task) {
            final title = task['title']?.toString() ?? '';
            final note = task['note']?.toString() ?? '';
            return fuzzyMatches(title, query) || fuzzyMatches(note, query);
          }).toList()..sort((a, b) {
            final scoreA = fuzzyScore((a['title'] ?? '').toString(), query);
            final scoreB = fuzzyScore((b['title'] ?? '').toString(), query);
            return scoreA.compareTo(scoreB);
          });
    }
    return tasks.map((task) {
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
      _scrollToHighlight();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(
        () => _highlightIndex =
            (_highlightIndex - 1 + visible.length) % visible.length,
      );
      _scrollToHighlight();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _sectionHeader(String title, ClarifyTokens t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: widget.textMuted,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _entryTile(
    _PaletteEntry entry,
    bool highlighted,
    ClarifyTokens t, {
    int? index,
  }) {
    return MouseRegion(
      onEnter: index == null ? null : (_) => _setHighlight(index),
      child: Material(
        color: highlighted ? t.accent.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(ClarifyRadius.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(ClarifyRadius.sm),
          onTap: () => _activate(entry),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  entry.icon,
                  size: 18,
                  color: highlighted ? t.accent : widget.textMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: widget.textColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      if (entry.subtitle != null && entry.subtitle!.isNotEmpty)
                        Text(
                          entry.subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: widget.textMuted,
                            fontSize: 12,
                          ),
                        ),
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

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final lang = widget.currentLang;
    final quickActions = _quickActions();
    final isEmptyQuery = _query.isEmpty;
    final isLoading = !isEmptyQuery && _query != _debouncedQuery;

    List<_PaletteEntry> visible = const [];
    Widget resultsChild;

    Widget tile(_PaletteEntry entry) {
      final idx = visible.indexOf(entry);
      return KeyedSubtree(
        key: idx >= 0 && idx < _itemKeys.length ? _itemKeys[idx] : null,
        child: _entryTile(entry, idx == _highlightIndex, t, index: idx),
      );
    }

    if (isEmptyQuery) {
      final allEntries = [...quickActions, ..._taskEntries('')];
      final recentEntries = _paletteRecentKeys
          .map((key) => _findByKey(allEntries, key))
          .whereType<_PaletteEntry>()
          .toList();
      visible = [...recentEntries, ...quickActions];
      _ensureItemKeys(visible.length);
      final rows = <Widget>[
        if (recentEntries.isNotEmpty) ...[
          _sectionHeader("Недавние".tr(lang), t),
          for (final entry in recentEntries) tile(entry),
        ],
        _sectionHeader("Быстрые действия".tr(lang), t),
        for (final entry in quickActions) tile(entry),
      ];
      resultsChild = ListView(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        children: rows,
      );
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
      final matchingActions =
          quickActions
              .where((a) => fuzzyMatches(a.title, _debouncedQuery))
              .toList()
            ..sort(
              (a, b) => fuzzyScore(
                a.title,
                _debouncedQuery,
              ).compareTo(fuzzyScore(b.title, _debouncedQuery)),
            );
      final matches = [...matchingActions, ..._taskEntries(_debouncedQuery)];
      if (matches.isEmpty) {
        final askEntry = _PaletteEntry(
          key: 'suggestion:askAi',
          icon: LucideIcons.sparkles,
          title: '${"Спросить AI".tr(lang)}: "$_debouncedQuery"',
          onSelect: () => widget.onAskAi(_debouncedQuery),
        );
        visible = [askEntry];
        _ensureItemKeys(visible.length);
        resultsChild = ListView(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                "Ничего не найдено".tr(lang),
                style: TextStyle(color: widget.textMuted),
              ),
            ),
            tile(askEntry),
          ],
        );
      } else {
        visible = matches;
        _ensureItemKeys(visible.length);
        resultsChild = ListView(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          children: [for (final entry in matches) tile(entry)],
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: ClarifyTextField(
                      controller: _controller,
                      autofocus: true,
                      style: TextStyle(color: widget.textColor, fontSize: 18),
                      hintText: "Команда, раздел или задача...".tr(lang),
                      prefixIcon: Icon(
                        LucideIcons.search,
                        color: t.accent,
                        size: 24,
                      ),
                      onChanged: _handleChanged,
                      onSubmitted: (_) {
                        if (effectiveIndex >= 0) {
                          _activate(visible[effectiveIndex]);
                        }
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
