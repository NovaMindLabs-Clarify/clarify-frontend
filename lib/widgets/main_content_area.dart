import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/priority.dart';
import '../core/localization.dart';
import '../core/tags.dart';
import '../core/theme/design_tokens.dart';
import 'calendar_day_timeline.dart';
import 'clarify_cascade_item.dart';
import 'clarify_glass.dart';
import 'clarify_list_entrance.dart';
import 'clarify_press_glow.dart';
import 'clarify_surface.dart';
import 'friends_screen.dart';
import 'messenger_shell.dart';
import 'project_kanban_board.dart';
import 'projects_screen.dart';

const List<String> _kWeekdaysRu = ['понедельник', 'вторник', 'среда', 'четверг', 'пятница', 'суббота', 'воскресенье'];

String _formatDate(DateTime date) {
  // Возвращаем правильный формат ДД.ММ.ГГГГ, чтобы он совпадал с БД
  return "${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}";
}

String _capitalize(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1).toLowerCase();
}

class MainContentArea extends StatelessWidget {
  final String selectedMenu;
  final String currentLang;
  final List<Map<String, dynamic>> filteredTasks;
  final bool isDark;
  final double scale;
  
  // Коллбеки для действий, чтобы виджет мог общаться с главным экраном
  final Function(int, int, List<Map<String, dynamic>>) onReorderTasks;
  final Function(Map<String, dynamic>, String, int) onTaskDropped;
  final Function(DateTime, int) onPlusTap;
  final Widget Function(Map<String, dynamic>) buildListTaskCard;
  final Widget Function(Map<String, dynamic>) buildBoardTaskCardExpanded;
  final Widget Function(Map<String, dynamic>) buildCalendarTaskCard;
  final Widget Function({required Widget child, EdgeInsetsGeometry? margin, EdgeInsetsGeometry? padding, Color? customColor}) buildGlassContainer;
  final Widget Function() buildStatisticsDashboard;
  final String Function(dynamic taskId) getLocalKanbanStatus;
  final void Function(dynamic taskId, String status) onSetLocalKanbanStatus;

  // Дата календаря передается как состояние
  final DateTime currentCalendarDate;
  final Function(DateTime) onCalendarDateChanged;

  // Экран "Проекты" — список авто-папок по тегам (см. projects_screen.dart).
  final Function(String) onMenuSelected;
  final Map<String, String> projectIconKeys;
  final void Function(String tag, String iconKey) onSetProjectIcon;
  final Map<String, int> projectColorKeys;
  final void Function(String tag, int colorIndex) onSetProjectColor;

  // Сортировка плоских списков — по времени (дефолт) или по приоритету
  // (MISSING_FEATURES P1.3). Не применяется во "Входящих" — там порядок
  // задаётся вручную перетаскиванием (см. комментарий у ReorderableListView ниже).
  final bool sortByPriority;
  final VoidCallback onToggleSortByPriority;

  // Открыть личный чат в мессенджере (из карточки друга/профиля) — вместо
  // Navigator.push поверх всего шелла (тогда пропадали бы сайдбар и список
  // чатов, ломая 3-колоночный макет). Родитель переключает selectedMenu на
  // 'Сообщения' и прокидывает выбранного партнёра сюда же.
  final String? pendingChatPartnerId;
  final String? pendingChatPartnerName;
  final void Function(String partnerId, String partnerName)? onOpenDirectChat;

  const MainContentArea({
    Key? key,
    required this.selectedMenu,
    required this.currentLang,
    required this.filteredTasks,
    required this.isDark,
    required this.scale,
    required this.onReorderTasks,
    required this.onTaskDropped,
    required this.onPlusTap,
    required this.buildListTaskCard,
    required this.buildBoardTaskCardExpanded,
    required this.buildCalendarTaskCard,
    required this.buildGlassContainer,
    required this.buildStatisticsDashboard,
    required this.getLocalKanbanStatus,
    required this.onSetLocalKanbanStatus,
    required this.currentCalendarDate,
    required this.onCalendarDateChanged,
    required this.onMenuSelected,
    required this.projectIconKeys,
    required this.onSetProjectIcon,
    required this.projectColorKeys,
    required this.onSetProjectColor,
    required this.sortByPriority,
    required this.onToggleSortByPriority,
    this.pendingChatPartnerId,
    this.pendingChatPartnerName,
    this.onOpenDirectChat,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final t = isDark ? ClarifyTokens.dark : ClarifyTokens.light;
    final textColor = t.text;
    final textMuted = t.text2;
    final glassBorderColor = t.border;
    final highlightColor = t.accentSoft;
    final emptyCellColor = t.surfaceSunken.withValues(alpha: isDark ? 0.5 : 0.6);

    final List<String> weekdaysRu = _kWeekdaysRu;

    const reservedMenuKeys = {'Мой день', 'Следующие 7 дней', 'Все задачи', 'Календарь', 'Входящие', 'Проекты', 'Друзья', 'Сообщения', 'Статистика'};
    final isTagProject = !reservedMenuKeys.contains(selectedMenu) && !selectedMenu.startsWith('ws_');

    if (isTagProject) {
      // Проект — авто-папка по тегу, доска (Не начато/В работе/Готово), а не
      // плоский список. См. REDESIGN_V2_PLAN.md §3.5, REDESIGN_V3_PLAN.md §3.17/5.16.
      final storedColorIndex = projectColorKeys[selectedMenu];
      final projectColor = storedColorIndex != null && storedColorIndex < t.tagPalette.length
          ? t.tagPalette[storedColorIndex]
          : t.tagPalette[selectedMenu.hashCode.abs() % t.tagPalette.length];
      final projectTasks = filteredTasks.where((task) {
        final tags = parseTagsString(task['tags']);
        return tags.contains(selectedMenu) && task['parent_id'] == null;
      }).toList();
      return ProjectKanbanBoard(
        projectName: selectedMenu,
        projectColor: projectColor,
        currentLang: currentLang,
        scale: scale,
        tasks: projectTasks,
        getLocalStatus: getLocalKanbanStatus,
        onSetLocalStatus: onSetLocalKanbanStatus,
        buildBoardTaskCardExpanded: buildBoardTaskCardExpanded,
        buildGlassContainer: buildGlassContainer,
      );
    }
    else if (selectedMenu == 'Все задачи' || selectedMenu == 'Мой день' || selectedMenu == 'Входящие' || selectedMenu.startsWith('ws_')) {
      List<Map<String, dynamic>> targetTasks = filteredTasks;

      if (selectedMenu == 'Мой день') {
        final todayStr = _formatDate(DateTime.now());
        targetTasks = filteredTasks.where((t) => t['due_date'] == todayStr && t['parent_id'] == null).toList();
      } else if (selectedMenu == 'Входящие') {
        targetTasks = filteredTasks.where((t) => (t['due_date'] == null || t['due_date'] == '') && t['parent_id'] == null).toList();
      } else if (selectedMenu.startsWith('ws_')) {
        int wsId = int.parse(selectedMenu.substring(3));
        targetTasks = filteredTasks.where((t) => t['workspace_id'] == wsId && t['parent_id'] == null).toList();
      } else {
        targetTasks = filteredTasks.where((t) => t['parent_id'] == null).toList();
      }

      // Одинаковое время (чаще всего — у обеих задач его вообще нет) раньше
      // ничем не разрешалось, порядок был случайным (как пришло с сервера) —
      // разнородные по смыслу задачи оказывались вперемешку. Группировка по
      // первому тегу для таких "ничьих" снижает стоимость переключения
      // контекста между разными по смыслу задачами, не трогая порядок для
      // задач, у которых время реально задано и различается.
      int sameTimeTiebreak(Map<String, dynamic> a, Map<String, dynamic> b) {
        final tagsA = parseTagsString(a['tags']);
        final tagsB = parseTagsString(b['tags']);
        return (tagsA.isEmpty ? '' : tagsA.first).compareTo(tagsB.isEmpty ? '' : tagsB.first);
      }

      final effectiveSortByPriority = sortByPriority && selectedMenu != 'Входящие';
      if (effectiveSortByPriority) {
        targetTasks.sort((a, b) {
          final rankCompare = priorityRank(a['priority']).compareTo(priorityRank(b['priority']));
          if (rankCompare != 0) return rankCompare;
          final timeCompare = (a['due_time'] ?? '23:59').compareTo(b['due_time'] ?? '23:59');
          if (timeCompare != 0) return timeCompare;
          return sameTimeTiebreak(a, b);
        });
      } else {
        targetTasks.sort((a, b) {
          final timeCompare = (a['due_time'] ?? '23:59').compareTo(b['due_time'] ?? '23:59');
          if (timeCompare != 0) return timeCompare;
          return sameTimeTiebreak(a, b);
        });
      }
      if (targetTasks.isEmpty) {
        final String emptyKey;
        if (selectedMenu == 'Мой день') {
          emptyKey = 'На сегодня ничего не запланировано';
        } else if (selectedMenu == 'Входящие') {
          emptyKey = 'Во входящих пока пусто';
        } else if (selectedMenu.startsWith('ws_')) {
          emptyKey = 'В этой команде пока нет задач';
        } else {
          emptyKey = 'Задач пока нет';
        }
        return Center(child: Text(emptyKey.tr(currentLang), style: TextStyle(color: textMuted, fontSize: 18)));
      }

      final sortToggle = selectedMenu == 'Входящие'
          ? null
          : Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Row(
                children: [
                  Icon(LucideIcons.arrowUpDown, size: 15, color: textMuted),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: sortByPriority ? onToggleSortByPriority : null,
                    child: Text(
                      'По времени'.tr(currentLang),
                      style: TextStyle(color: sortByPriority ? textMuted : t.accent, fontWeight: sortByPriority ? FontWeight.normal : FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 14),
                  GestureDetector(
                    onTap: sortByPriority ? null : onToggleSortByPriority,
                    child: Text(
                      'По приоритету'.tr(currentLang),
                      style: TextStyle(color: sortByPriority ? t.accent : textMuted, fontWeight: sortByPriority ? FontWeight.bold : FontWeight.normal, fontSize: 13),
                    ),
                  ),
                ],
              ),
            );

      if (selectedMenu == 'Входящие') {
        // Единственное место, где остаётся drag — здесь у задач нет даты,
        // поэтому порядок в списке ничем, кроме самого пользователя, не
        // задан; перетаскивание — единственный способ его выставить вручную.
        //
        // buildDefaultDragHandles:false + свой ReorderableDragStartListener —
        // дефолтная ручка Flutter на десктопе накладывается Positioned'ом
        // поверх карточки по правому краю, центрированная по ВСЕЙ высоте
        // плитки, а не по верху, как крестик удаления внутри самой карточки —
        // отсюда ручка и крестик были на разных высотах.
        //
        // proxyDecorator переопределён — дефолтный оборачивает перетаскиваемый
        // элемент в `Material(elevation: ...)` БЕЗ borderRadius/shape; поверх
        // скруглённой стеклянной карточки (ClipRRect + BackdropFilter внутри
        // buildGlassContainer) это давало несовпадающие границы тени/клипа —
        // отсюда "режется криво" при зажатой ручке. Лёгкий scale вместо
        // elevation не конфликтует со скруглением/блюром карточки.
        return ClarifyListEntrance(
          child: ReorderableListView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            buildDefaultDragHandles: false,
            proxyDecorator: (child, index, animation) {
              return AnimatedBuilder(
                animation: animation,
                builder: (context, _) {
                  final t = ClarifyMotion.spring.transform(animation.value);
                  return Transform.scale(scale: 1.0 + 0.02 * t, child: child);
                },
                child: child,
              );
            },
            onReorder: (int oldIndex, int newIndex) {
              onReorderTasks(oldIndex, newIndex, targetTasks);
            },
            children: targetTasks.asMap().entries.map((entry) {
              final index = entry.key;
              final task = entry.value;
              return ClarifyCascadeItem(
                key: ValueKey('cascade_${task['id']}'),
                index: index,
                child: Row(
                  key: ValueKey(task['id'].toString()),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: buildListTaskCard(task)),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, top: 14),
                      child: ReorderableDragStartListener(
                        index: index,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.grab,
                          child: Icon(LucideIcons.gripVertical, size: 18, color: textMuted),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      } else {
        return ClarifyListEntrance(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (sortToggle != null) sortToggle,
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: targetTasks.asMap().entries.map((entry) {
                    return ClarifyCascadeItem(
                      key: ValueKey('cascade_${entry.value['id']}'),
                      index: entry.key,
                      child: buildListTaskCard(entry.value),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      }
    }
    else if (selectedMenu == 'Следующие 7 дней') {
      // Содержимое колонки без внешней обёртки (Expanded/SizedBox) — она отличается
      // между брейкпоинтами, сама колонка — нет.
      Widget dayColumn(int index) {
        final targetDate = DateTime.now().add(Duration(days: index));
        final dateStr = _formatDate(targetDate);
        final dayTasks = filteredTasks.where((t) => t['due_date'] == dateStr && t['parent_id'] == null).toList();
        dayTasks.sort((a, b) => (a['due_time'] ?? '23:59').compareTo(b['due_time'] ?? '23:59'));

        final weekdayName = _capitalize(weekdaysRu[targetDate.weekday - 1]);
        String title = index == 0 ? 'Сегодня'.tr(currentLang) : (index == 1 ? 'Завтра'.tr(currentLang) : weekdayName);
        String subtitle = index < 2 ? weekdayName : "${targetDate.day.toString().padLeft(2, '0')}.${targetDate.month.toString().padLeft(2, '0')}";

        final bool isToday = index == 0;

        return DragTarget<Map<String, dynamic>>(
          onAccept: (Map<String, dynamic> task) => onTaskDropped(task, dateStr, dayTasks.length),
          builder: (context, candidateData, rejectedData) {
            return buildGlassContainer(
              margin: EdgeInsets.only(right: index == 6 ? 0 : 12 * scale),
              customColor: candidateData.isNotEmpty ? highlightColor : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Акцент "Сегодня" — полоса слева у заголовка, тот же приём,
                  // что уже используется в MobileTaskRow/аккаунт-блоке сайдбара,
                  // а не постоянная заливка фона (она уже занята drag-hover'ом).
                  Container(
                    padding: EdgeInsets.fromLTRB((isToday ? 13 : 16) * scale, 20 * scale, 16 * scale, 12 * scale),
                    decoration: isToday ? BoxDecoration(border: Border(left: BorderSide(color: t.accent, width: 3 * scale))) : null,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title.tr(currentLang), style: TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.bold, color: isToday ? t.accent : textColor), maxLines: 1, overflow: TextOverflow.ellipsis), SizedBox(height: 4 * scale), Text(subtitle.tr(currentLang), style: TextStyle(fontSize: 13 * scale, color: textMuted, fontWeight: FontWeight.w600))]),
                  ),
                  Padding(padding: EdgeInsets.fromLTRB(12 * scale, 0, 12 * scale, 16 * scale), child: InkWell(borderRadius: BorderRadius.circular(12 * scale), onTap: () => onPlusTap(targetDate, dayTasks.length), child: Container(width: double.infinity, padding: EdgeInsets.symmetric(vertical: 6 * scale), decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(12 * scale), border: Border.all(color: glassBorderColor, width: 1.0)), child: Icon(LucideIcons.plus, size: 16 * scale, color: textMuted)), ), ),
                  // Компактная карточка (та же, что в ячейках Календаря) вместо
                  // buildBoardTaskCardExpanded — единый визуальный язык; сама
                  // buildCalendarTaskCard уже оборачивает в LongPressDraggable.
                  Expanded(child: ListView.builder(padding: EdgeInsets.symmetric(horizontal: 12 * scale), itemCount: dayTasks.length, itemBuilder: (context, taskIndex) => buildCalendarTaskCard(dayTasks[taskIndex]))),
                ],
              ),
            );
          },
        );
      }

      return LayoutBuilder(builder: (context, constraints) {
        // Компакт: колонки не сжимаются ниже читаемой ширины — вместо этого
        // весь ряд скроллится горизонтально. Раньше все 7 колонок делили
        // ширину поровну и на узких окнах превращались в нечитаемые полоски.
        if (ClarifyBreakpoints.of(constraints.maxWidth) == ClarifyBreakpoint.compact) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 8 * scale),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 24 * scale),
              itemCount: 7,
              itemBuilder: (context, index) => SizedBox(width: 240 * scale, child: dayColumn(index)),
            ),
          );
        }
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 8 * scale),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: List.generate(7, (index) => Expanded(child: dayColumn(index))),
          ),
        );
      });
    }
    else if (selectedMenu == 'Календарь') {
      return _CalendarSection(
        currentLang: currentLang,
        scale: scale,
        isDark: isDark,
        t: t,
        textColor: textColor,
        textMuted: textMuted,
        highlightColor: highlightColor,
        emptyCellColor: emptyCellColor,
        filteredTasks: filteredTasks,
        buildGlassContainer: buildGlassContainer,
        buildCalendarTaskCard: buildCalendarTaskCard,
        buildListTaskCard: buildListTaskCard,
        onTaskDropped: onTaskDropped,
        onPlusTap: onPlusTap,
        currentCalendarDate: currentCalendarDate,
        onCalendarDateChanged: onCalendarDateChanged,
      );
    }
    else if (selectedMenu == 'Друзья') {
      return FriendsScreen(
        currentLang: currentLang,
        scale: scale,
        buildGlassContainer: buildGlassContainer,
        onOpenConversation: (partnerId, name) => onOpenDirectChat?.call(partnerId, name),
      );
    }
    else if (selectedMenu == 'Сообщения') {
      return MessengerShell(
        currentLang: currentLang,
        scale: scale,
        buildGlassContainer: buildGlassContainer,
        initialPartnerId: pendingChatPartnerId,
        initialPartnerName: pendingChatPartnerName,
      );
    }
    else if (selectedMenu == 'Статистика') {
      return buildStatisticsDashboard();
    }
    else if (selectedMenu == 'Проекты') {
      return ProjectsScreen(
        isDark: isDark,
        currentLang: currentLang,
        scale: scale,
        tasks: filteredTasks,
        projectIconKeys: projectIconKeys,
        onSetProjectIcon: onSetProjectIcon,
        projectColorKeys: projectColorKeys,
        onSetProjectColor: onSetProjectColor,
        onOpenProject: onMenuSelected,
      );
    }
    return const SizedBox.shrink();
  }
}

/// Попап выбора месяца/года по клику на заголовок "Июль 2026" — без него
/// смена года требовала пролистать стрелками до 12 раз (REDESIGN_V3_PLAN.md
/// §5.10). Год листается стрелками, месяц — сеткой 3×4, тот же стеклянный
/// стиль, что и у showClarifyDatePicker.
Future<DateTime?> _showMonthYearPicker(BuildContext context, bool isDark, DateTime current) {
  return showClarifySurface<DateTime>(
    context: context,
    builder: (context) => _MonthYearPickerDialog(isDark: isDark, initial: current),
  );
}

class _MonthYearPickerDialog extends StatefulWidget {
  final bool isDark;
  final DateTime initial;

  const _MonthYearPickerDialog({required this.isDark, required this.initial});

  @override
  State<_MonthYearPickerDialog> createState() => _MonthYearPickerDialogState();
}

class _MonthYearPickerDialogState extends State<_MonthYearPickerDialog> {
  late int _year;
  static const _monthsRu = ['Янв', 'Фев', 'Мар', 'Апр', 'Май', 'Июн', 'Июл', 'Авг', 'Сен', 'Окт', 'Ноя', 'Дек'];

  @override
  void initState() {
    super.initState();
    _year = widget.initial.year;
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.isDark ? ClarifyTokens.dark : ClarifyTokens.light;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: ClarifyGlass(
          borderRadius: BorderRadius.circular(ClarifyRadius.lg),
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(icon: Icon(LucideIcons.chevronLeft, color: t.text), onPressed: () => setState(() => _year--)),
                    Text('$_year', style: TextStyle(color: t.text, fontWeight: FontWeight.bold, fontSize: 18)),
                    IconButton(icon: Icon(LucideIcons.chevronRight, color: t.text), onPressed: () => setState(() => _year++)),
                  ],
                ),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 1.6, crossAxisSpacing: 8, mainAxisSpacing: 8),
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    final monthNum = index + 1;
                    final isSelected = _year == widget.initial.year && monthNum == widget.initial.month;
                    return Material(
                      color: isSelected ? t.accent : t.surfaceSunken,
                      borderRadius: BorderRadius.circular(ClarifyRadius.sm),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(ClarifyRadius.sm),
                        onTap: () => Navigator.of(context).pop(DateTime(_year, monthNum)),
                        child: Center(
                          child: Text(_monthsRu[index], style: TextStyle(color: isSelected ? t.onAccent : t.text, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Обёртка "Календаря" (REDESIGN_V4_PLAN.md §6.5): таймлайн дня — основной
/// вид на десктопе, месячная сетка — вторичный режим "обзор", переключаемый
/// явно кнопками в шапке. Выбранный день таймлайна хранится отдельно от
/// курсора месяца (currentCalendarDate/onCalendarDateChanged, приходит из
/// родителя) — переключение вида не должно сбрасывать позицию в другом.
class _CalendarSection extends StatefulWidget {
  final String currentLang;
  final double scale;
  final bool isDark;
  final ClarifyTokens t;
  final Color textColor;
  final Color textMuted;
  final Color highlightColor;
  final Color emptyCellColor;
  final List<Map<String, dynamic>> filteredTasks;
  final Widget Function({required Widget child, EdgeInsetsGeometry? margin, EdgeInsetsGeometry? padding, Color? customColor}) buildGlassContainer;
  final Widget Function(Map<String, dynamic>) buildCalendarTaskCard;
  final Widget Function(Map<String, dynamic>) buildListTaskCard;
  final Function(Map<String, dynamic>, String, int) onTaskDropped;
  final Function(DateTime, int) onPlusTap;
  final DateTime currentCalendarDate;
  final Function(DateTime) onCalendarDateChanged;

  const _CalendarSection({
    required this.currentLang,
    required this.scale,
    required this.isDark,
    required this.t,
    required this.textColor,
    required this.textMuted,
    required this.highlightColor,
    required this.emptyCellColor,
    required this.filteredTasks,
    required this.buildGlassContainer,
    required this.buildCalendarTaskCard,
    required this.buildListTaskCard,
    required this.onTaskDropped,
    required this.onPlusTap,
    required this.currentCalendarDate,
    required this.onCalendarDateChanged,
  });

  @override
  State<_CalendarSection> createState() => _CalendarSectionState();
}

class _CalendarSectionState extends State<_CalendarSection> {
  bool _timelineMode = true;
  late DateTime _selectedDay;

  static const List<String> _monthsRu = ['', 'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь', 'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'];

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
  }

  Widget _modeToggleButton(IconData icon, bool selected, VoidCallback onTap, String tooltip) {
    final t = widget.t;
    final s = widget.scale;
    return Tooltip(
      message: tooltip,
      child: ClarifyPressGlow(
        color: t.accent,
        spread: 10 * s,
        child: InkWell(
          borderRadius: BorderRadius.circular(ClarifyRadius.sm),
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.all(6 * s),
            decoration: BoxDecoration(
              color: selected ? t.accent.withValues(alpha: 0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(ClarifyRadius.sm),
            ),
            child: Icon(icon, size: 18 * s, color: selected ? t.accent : widget.textMuted),
          ),
        ),
      ),
    );
  }

  Widget _dayHeaderLabel() {
    final s = widget.scale;
    final isToday = _formatDate(_selectedDay) == _formatDate(DateTime.now());
    final weekday = _capitalize(_kWeekdaysRu[_selectedDay.weekday - 1]);
    return Text(
      isToday
          ? "Сегодня".tr(widget.currentLang)
          : "$weekday, ${_selectedDay.day.toString().padLeft(2, '0')}.${_selectedDay.month.toString().padLeft(2, '0')}",
      style: TextStyle(fontSize: 24 * s, fontWeight: FontWeight.bold, color: widget.textColor),
    );
  }

  Widget _monthHeaderLabel(BuildContext context) {
    final s = widget.scale;
    final year = widget.currentCalendarDate.year;
    final month = widget.currentCalendarDate.month;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(ClarifyRadius.sm),
        onTap: () async {
          final picked = await _showMonthYearPicker(context, widget.isDark, widget.currentCalendarDate);
          if (picked != null) widget.onCalendarDateChanged(picked);
        },
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8 * s, vertical: 4 * s),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text("${_monthsRu[month].tr(widget.currentLang)} $year", style: TextStyle(fontSize: 24 * s, fontWeight: FontWeight.bold, color: widget.textColor)),
            SizedBox(width: 6 * s),
            Icon(LucideIcons.chevronDown, size: 18 * s, color: widget.textMuted),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.scale;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24 * s, vertical: 12 * s),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _timelineMode ? _dayHeaderLabel() : _monthHeaderLabel(context),
              Row(children: [
                if (_timelineMode) ...[
                  IconButton(icon: Icon(LucideIcons.chevronLeft, color: widget.textColor, size: 28 * s), onPressed: () => setState(() => _selectedDay = _selectedDay.subtract(const Duration(days: 1)))),
                  IconButton(icon: Icon(LucideIcons.chevronRight, color: widget.textColor, size: 28 * s), onPressed: () => setState(() => _selectedDay = _selectedDay.add(const Duration(days: 1)))),
                ] else ...[
                  IconButton(icon: Icon(LucideIcons.chevronLeft, color: widget.textColor, size: 28 * s), onPressed: () => widget.onCalendarDateChanged(DateTime(widget.currentCalendarDate.year, widget.currentCalendarDate.month - 1))),
                  IconButton(icon: Icon(LucideIcons.chevronRight, color: widget.textColor, size: 28 * s), onPressed: () => widget.onCalendarDateChanged(DateTime(widget.currentCalendarDate.year, widget.currentCalendarDate.month + 1))),
                ],
                SizedBox(width: 12 * s),
                _modeToggleButton(LucideIcons.clock, _timelineMode, () => setState(() => _timelineMode = true), "Таймлайн".tr(widget.currentLang)),
                SizedBox(width: 4 * s),
                _modeToggleButton(LucideIcons.grid3x3, !_timelineMode, () => setState(() => _timelineMode = false), "Месяц".tr(widget.currentLang)),
              ]),
            ],
          ),
        ),
        Expanded(
          child: _timelineMode ? _buildTimeline() : _buildMonthGrid(context),
        ),
      ],
    );
  }

  Widget _buildTimeline() {
    final dateStr = _formatDate(_selectedDay);
    final dayTasks = widget.filteredTasks.where((t) => t['due_date'] == dateStr && t['parent_id'] == null).toList();
    return CalendarDayTimeline(
      date: _selectedDay,
      tasks: dayTasks,
      buildCalendarTaskCard: widget.buildCalendarTaskCard,
      scale: widget.scale,
      t: widget.t,
      currentLang: widget.currentLang,
      onTaskDropped: (task, droppedDateStr) => widget.onTaskDropped(task, droppedDateStr, dayTasks.length),
    );
  }

  Widget _buildMonthGrid(BuildContext context) {
    final t = widget.t;
    final s = widget.scale;
    final year = widget.currentCalendarDate.year;
    final month = widget.currentCalendarDate.month;
    final firstDayOfMonth = DateTime(year, month, 1);
    final lastDayOfMonth = DateTime(year, month + 1, 0);
    final int startOffset = firstDayOfMonth.weekday - 1;
    final int totalDaysInMonth = lastDayOfMonth.day;
    final int totalCells = startOffset + totalDaysInMonth;

    return LayoutBuilder(builder: (context, outerConstraints) {
      final bool isCompactHeader = ClarifyBreakpoints.of(outerConstraints.maxWidth) == ClarifyBreakpoint.compact;
      final double headerCellWidth = isCompactHeader
          ? 150 * s
          : (outerConstraints.maxWidth - (48 * s) - (16 * s * 6)) / 7;

      // Только для компакт-режима (ListView.horizontal ниже) — Expanded здесь был бы
      // ошибкой: он валиден лишь прямым потомком Flex, а не SizedBox внутри ListView.
      final weekdayLabels = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'].map((day) => SizedBox(
            width: headerCellWidth,
            child: Center(child: Text(day.tr(widget.currentLang), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16 * s, color: widget.textMuted))),
          )).toList();

      return Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24 * s),
            child: isCompactHeader
                ? SizedBox(height: 24 * s, child: ListView(scrollDirection: Axis.horizontal, physics: const NeverScrollableScrollPhysics(), children: weekdayLabels))
                : Row(children: ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'].map((day) => Expanded(child: Center(child: Text(day.tr(widget.currentLang), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16 * s, color: widget.textMuted))))).toList()),
          ),
          SizedBox(height: 12 * s),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final int rows = (totalCells / 7).ceil();
                final bool isCompact = ClarifyBreakpoints.of(constraints.maxWidth) == ClarifyBreakpoint.compact;
                // Компакт: ячейка не сжимается ниже читаемой ширины — сетка целиком
                // скроллится по горизонтали, а не расплющивает 7 колонок в полоски
                // (как было раньше — childAspectRatio считался от всей доступной
                // ширины без нижней границы).
                final double cellWidth = isCompact
                    ? 150 * s
                    : (constraints.maxWidth - (48 * s) - (16 * s * 6)) / 7;
                final double cellHeight = (constraints.maxHeight - (48 * s) - (16 * s * (rows - 1))) / rows;
                final double childAspectRatio = (cellWidth > 0 && cellHeight > 0) ? (cellWidth / cellHeight) : 1.0;

                final grid = GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.all(24 * s),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    crossAxisSpacing: 16 * s,
                    mainAxisSpacing: 16 * s,
                    childAspectRatio: childAspectRatio,
                  ),
                  itemCount: totalCells,
                  itemBuilder: (context, index) {
                    if (index < startOffset) return const SizedBox.shrink();
                    final dayNumber = index - startOffset + 1;
                    final cellDate = DateTime(year, month, dayNumber);
                    final cellDateStr = _formatDate(cellDate);
                    final dayTasks = widget.filteredTasks.where((t) => t['due_date'] == cellDateStr && t['parent_id'] == null).toList();
                    dayTasks.sort((a, b) => (a['due_time'] ?? '23:59').compareTo(b['due_time'] ?? '23:59'));
                    final taskCount = dayTasks.length;
                    final dayTitle = "${_capitalize(_kWeekdaysRu[cellDate.weekday - 1])}, ${dayNumber.toString().padLeft(2, '0')}.${month.toString().padLeft(2, '0')}";
                    return DragTarget<Map<String, dynamic>>(
                      onAccept: (Map<String, dynamic> task) => widget.onTaskDropped(task, cellDateStr, taskCount),
                      builder: (context, candidateData, rejectedData) {
                        return widget.buildGlassContainer(
                          // Пустая ячейка — surfaceSunken, заполненная — обычная surface: два разных,
                          // но согласованных состояния вместо одинаковых голых прямоугольников
                          // (§9.3/DESIGN_IDEAS.md P1.4) — плюс приглушённая подпись "Свободно" в
                          // пустой ячейке вместо молчаливой пустоты.
                          customColor: candidateData.isNotEmpty ? widget.highlightColor : (taskCount == 0 ? widget.emptyCellColor : null),
                          padding: EdgeInsets.all(12 * s),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: EdgeInsets.only(bottom: 8 * s, left: 8 * s, top: 4 * s),
                                child: Text("$dayNumber", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18 * s, color: cellDateStr == _formatDate(DateTime.now()) ? t.accent : widget.textColor)),
                              ),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: taskCount == 0
                                          ? Center(child: Text("Свободно".tr(widget.currentLang), style: TextStyle(fontSize: 11 * s, color: widget.textMuted, fontWeight: FontWeight.w600)))
                                          : _CalendarDayTasksPreview(dayTitle: dayTitle, tasks: dayTasks, buildCalendarTaskCard: widget.buildCalendarTaskCard, buildListTaskCard: widget.buildListTaskCard, scale: s, t: t, currentLang: widget.currentLang),
                                    ),
                                    Align(alignment: Alignment.bottomCenter, child: InkWell(onTap: () => widget.onPlusTap(cellDate, taskCount), child: Padding(padding: EdgeInsets.only(bottom: 4 * s), child: Icon(LucideIcons.plus, color: widget.textMuted, size: 20 * s)))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );

                if (!isCompact) return grid;

                final totalGridWidth = (48 * s) + (7 * cellWidth) + (6 * 16 * s);
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(width: totalGridWidth, height: constraints.maxHeight, child: grid),
                );
              },
            ),
          ),
        ],
      );
    });
  }
}

/// До 3 задач прямо в ячейке + пилюля "+N ещё", открывающая полный список дня
/// попапом (REDESIGN_V3_PLAN.md §5.9: пейджер с точками/стрелками было
/// "криво" при 5+ задачах — заменено на google/apple-calendar паттерн, без
/// внутреннего свайпа и скачков раскладки сетки).
class _CalendarDayTasksPreview extends StatelessWidget {
  static const int _previewCount = 3;

  final String dayTitle;
  final List<Map<String, dynamic>> tasks;
  final Widget Function(Map<String, dynamic>) buildCalendarTaskCard;
  final Widget Function(Map<String, dynamic>) buildListTaskCard;
  final double scale;
  final ClarifyTokens t;
  final String currentLang;

  const _CalendarDayTasksPreview({
    required this.dayTitle,
    required this.tasks,
    required this.buildCalendarTaskCard,
    required this.buildListTaskCard,
    required this.scale,
    required this.t,
    required this.currentLang,
  });

  @override
  Widget build(BuildContext context) {
    final overflow = tasks.length - _previewCount;
    final previewTasks = overflow > 0 ? tasks.sublist(0, _previewCount) : tasks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ListView вместо просто Column детей — она сама клипует контент,
        // не помещающийся в отведённую высоту ячейки, вместо RenderFlex
        // overflow ("BOTTOM OVERFLOWED") на переполненных днях.
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            children: [for (final task in previewTasks) buildCalendarTaskCard(task)],
          ),
        ),
        if (overflow > 0)
          Padding(
            padding: EdgeInsets.only(top: 2 * scale),
            child: InkWell(
              borderRadius: BorderRadius.circular(ClarifyRadius.sm),
              onTap: () => showClarifySurface<void>(
                context: context,
                builder: (context) => _DayAgendaDialog(
                  dayTitle: dayTitle,
                  tasks: tasks,
                  buildListTaskCard: buildListTaskCard,
                  t: t,
                ),
              ),
              child: Text(
                "+$overflow ${'Ещё'.tr(currentLang)}",
                style: TextStyle(fontSize: 11 * scale, fontWeight: FontWeight.w600, color: t.text2),
              ),
            ),
          ),
      ],
    );
  }
}

/// Полный список задач дня — открывается по клику на пилюлю "+N ещё" в ячейке
/// календаря. Тот же стеклянный шаблон, что и у `_MonthYearPickerDialog`;
/// анимация вылета из точки клика уже даёт `showClarifySurface`.
class _DayAgendaDialog extends StatelessWidget {
  final String dayTitle;
  final List<Map<String, dynamic>> tasks;
  final Widget Function(Map<String, dynamic>) buildListTaskCard;
  final ClarifyTokens t;

  const _DayAgendaDialog({
    required this.dayTitle,
    required this.tasks,
    required this.buildListTaskCard,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: ClarifyGlass(
          borderRadius: BorderRadius.circular(ClarifyRadius.lg),
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
            child: SizedBox(
              width: 340,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(dayTitle, style: TextStyle(color: t.text, fontWeight: FontWeight.bold, fontSize: 18)),
                      IconButton(icon: Icon(LucideIcons.x, color: t.text2), onPressed: () => Navigator.of(context).pop()),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: tasks.map(buildListTaskCard).toList(),
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
