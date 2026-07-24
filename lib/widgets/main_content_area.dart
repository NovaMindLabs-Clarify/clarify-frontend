import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/localization.dart';
import '../core/theme/design_tokens.dart';
import 'clarify_glass.dart';
import 'clarify_list_entrance.dart';
import 'clarify_surface.dart';
import 'conversations_screen.dart';
import 'friends_screen.dart';
import 'user_profile_modal.dart';
import 'project_kanban_board.dart';

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
  }) : super(key: key);

  String _formatDate(DateTime date) {
    // Возвращаем правильный формат ДД.ММ.ГГГГ, чтобы он совпадал с БД
    return "${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}";
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final t = isDark ? ClarifyTokens.dark : ClarifyTokens.light;
    final textColor = t.text;
    final textMuted = t.text2;
    final glassBorderColor = t.border;
    final highlightColor = t.accentSoft;
    final emptyCellColor = t.surfaceSunken.withValues(alpha: isDark ? 0.5 : 0.6);
    
    final List<String> weekdaysRu = ['понедельник', 'вторник', 'среда', 'четверг', 'пятница', 'суббота', 'воскресенье'];

    const reservedMenuKeys = {'Мой день', 'Следующие 7 дней', 'Все задачи', 'Календарь', 'Входящие', 'Друзья', 'Сообщения', 'Статистика'};
    final isTagProject = !reservedMenuKeys.contains(selectedMenu) && !selectedMenu.startsWith('ws_');

    if (isTagProject) {
      // Проект — авто-папка по тегу, доска (Не начато/В работе/Готово), а не
      // плоский список. См. REDESIGN_V2_PLAN.md §3.5, REDESIGN_V3_PLAN.md §3.17/5.16.
      final projectColor = t.tagPalette[selectedMenu.hashCode.abs() % t.tagPalette.length];
      final projectTasks = filteredTasks.where((task) {
        final tags = (task['tags']?.toString() ?? '').split(',').map((e) => e.trim());
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

      targetTasks.sort((a, b) => (a['due_time'] ?? '23:59').compareTo(b['due_time'] ?? '23:59'));
      if (targetTasks.isEmpty) return Center(child: Text("Пусто. Отдыхаем!".tr(currentLang), style: TextStyle(color: textMuted, fontSize: 18)));

      if (selectedMenu == 'Входящие') {
        // Единственное место, где остаётся drag — здесь у задач нет даты,
        // поэтому порядок в списке ничем, кроме самого пользователя, не
        // задан; перетаскивание — единственный способ его выставить вручную.
        // ReorderableListView сам считает feedback по реальному размеру
        // элемента — раньше здесь был LongPressDraggable с фиксированной
        // шириной feedback (500px), из-за чего при перетаскивании карточка
        // "резалась криво", если реальная колонка была уже/шире 500px.
        return ClarifyListEntrance(
          child: ReorderableListView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            onReorder: (int oldIndex, int newIndex) {
              onReorderTasks(oldIndex, newIndex, targetTasks);
            },
            children: targetTasks.map((task) {
              return Container(
                key: ValueKey(task['id'].toString()),
                child: buildListTaskCard(task),
              );
            }).toList(),
          ),
        );
      } else {
        return ClarifyListEntrance(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: targetTasks.map((task) => buildListTaskCard(task)).toList(),
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

        return DragTarget<Map<String, dynamic>>(
          onAccept: (Map<String, dynamic> task) => onTaskDropped(task, dateStr, dayTasks.length),
          builder: (context, candidateData, rejectedData) {
            return buildGlassContainer(
              margin: EdgeInsets.only(right: index == 6 ? 0 : 12 * scale),
              customColor: candidateData.isNotEmpty ? highlightColor : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(padding: EdgeInsets.fromLTRB(16 * scale, 20 * scale, 16 * scale, 12 * scale), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title.tr(currentLang), style: TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.bold, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis), SizedBox(height: 4 * scale), Text(subtitle.tr(currentLang), style: TextStyle(fontSize: 13 * scale, color: textMuted, fontWeight: FontWeight.w600))])),
                  Padding(padding: EdgeInsets.fromLTRB(12 * scale, 0, 12 * scale, 16 * scale), child: InkWell(borderRadius: BorderRadius.circular(12 * scale), onTap: () => onPlusTap(targetDate, dayTasks.length), child: Container(width: double.infinity, padding: EdgeInsets.symmetric(vertical: 6 * scale), decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(12 * scale), border: Border.all(color: glassBorderColor, width: 1.0)), child: Icon(LucideIcons.plus, size: 16 * scale, color: textMuted)), ), ),
                  Expanded(child: ListView.builder(padding: EdgeInsets.symmetric(horizontal: 12 * scale), itemCount: dayTasks.length, itemBuilder: (context, taskIndex) { final task = dayTasks[taskIndex]; return LongPressDraggable<Map<String, dynamic>>(data: task, delay: const Duration(milliseconds: 200), feedback: Material(color: Colors.transparent, child: SizedBox(width: 250 * scale, child: buildBoardTaskCardExpanded(task))), childWhenDragging: Opacity(opacity: 0.3, child: buildBoardTaskCardExpanded(task)), child: buildBoardTaskCardExpanded(task)); }), ),
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
      final year = currentCalendarDate.year; final month = currentCalendarDate.month;
      final firstDayOfMonth = DateTime(year, month, 1); final lastDayOfMonth = DateTime(year, month + 1, 0);
      final int startOffset = firstDayOfMonth.weekday - 1; final int totalDaysInMonth = lastDayOfMonth.day; final int totalCells = startOffset + totalDaysInMonth;
      final List<String> monthsRu = ['', 'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь', 'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'];

      return LayoutBuilder(builder: (context, outerConstraints) {
        final bool isCompactHeader = ClarifyBreakpoints.of(outerConstraints.maxWidth) == ClarifyBreakpoint.compact;
        final double headerCellWidth = isCompactHeader
            ? 150 * scale
            : (outerConstraints.maxWidth - (48 * scale) - (16 * scale * 6)) / 7;

        // Только для компакт-режима (ListView.horizontal ниже) — Expanded здесь был бы
        // ошибкой: он валиден лишь прямым потомком Flex, а не SizedBox внутри ListView.
        final weekdayLabels = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'].map((day) => SizedBox(
              width: headerCellWidth,
              child: Center(child: Text(day.tr(currentLang), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16 * scale, color: textMuted))),
            )).toList();

        return Column(
        children: [
          Padding(padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 12 * scale), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(ClarifyRadius.sm),
                onTap: () async {
                  final picked = await _showMonthYearPicker(context, isDark, currentCalendarDate);
                  if (picked != null) onCalendarDateChanged(picked);
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 4 * scale),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text("${monthsRu[month].tr(currentLang)} $year", style: TextStyle(fontSize: 24 * scale, fontWeight: FontWeight.bold, color: textColor)),
                    SizedBox(width: 6 * scale),
                    Icon(LucideIcons.chevronDown, size: 18 * scale, color: textMuted),
                  ]),
                ),
              ),
            ),
            Row(children: [IconButton(icon: Icon(LucideIcons.chevronLeft, color: textColor, size: 28 * scale), onPressed: () => onCalendarDateChanged(DateTime(year, month - 1))), IconButton(icon: Icon(LucideIcons.chevronRight, color: textColor, size: 28 * scale), onPressed: () => onCalendarDateChanged(DateTime(year, month + 1))), ], )], ), ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24 * scale),
            child: isCompactHeader
                ? SizedBox(height: 24 * scale, child: ListView(scrollDirection: Axis.horizontal, physics: const NeverScrollableScrollPhysics(), children: weekdayLabels))
                : Row(children: ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'].map((day) => Expanded(child: Center(child: Text(day.tr(currentLang), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16 * scale, color: textMuted))))).toList()),
          ),
          SizedBox(height: 12 * scale),
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
                    ? 150 * scale
                    : (constraints.maxWidth - (48 * scale) - (16 * scale * 6)) / 7;
                final double cellHeight = (constraints.maxHeight - (48 * scale) - (16 * scale * (rows - 1))) / rows;
                final double childAspectRatio = (cellWidth > 0 && cellHeight > 0) ? (cellWidth / cellHeight) : 1.0;

                final grid = GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.all(24 * scale),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    crossAxisSpacing: 16 * scale,
                    mainAxisSpacing: 16 * scale,
                    childAspectRatio: childAspectRatio
                  ),
                  itemCount: totalCells,
                  itemBuilder: (context, index) {
                    if (index < startOffset) return const SizedBox.shrink(); 
                    final dayNumber = index - startOffset + 1; final cellDate = DateTime(year, month, dayNumber); final cellDateStr = _formatDate(cellDate);
                    final dayTasks = filteredTasks.where((t) => t['due_date'] == cellDateStr && t['parent_id'] == null).toList();
                    dayTasks.sort((a, b) => (a['due_time'] ?? '23:59').compareTo(b['due_time'] ?? '23:59'));
                    final taskCount = dayTasks.length;
                    return DragTarget<Map<String, dynamic>>(
                      onAccept: (Map<String, dynamic> task) => onTaskDropped(task, cellDateStr, taskCount),
                      builder: (context, candidateData, rejectedData) {
                        return buildGlassContainer(
                          // Пустая ячейка — surfaceSunken, заполненная — обычная surface: два разных,
                          // но согласованных состояния вместо одинаковых голых прямоугольников.
                          customColor: candidateData.isNotEmpty ? highlightColor : (taskCount == 0 ? emptyCellColor : null),
                          padding: EdgeInsets.all(12 * scale),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(padding: EdgeInsets.only(bottom: 8 * scale, left: 8 * scale, top: 4 * scale), child: Text("$dayNumber", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18 * scale, color: cellDateStr == _formatDate(DateTime.now()) ? t.accent : textColor)),),
                              Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Expanded(child: _CalendarDayTasksPager(tasks: dayTasks, buildCalendarTaskCard: buildCalendarTaskCard, scale: scale, dotColor: t.accent, dotColorInactive: glassBorderColor)),
                                Align(alignment: Alignment.bottomCenter, child: InkWell(onTap: () => onPlusTap(cellDate, taskCount), child: Padding(padding: EdgeInsets.only(bottom: 4 * scale), child: Icon(LucideIcons.plus, color: textMuted, size: 20 * scale), ), ), ),
                              ], ), ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );

                if (!isCompact) return grid;

                final totalGridWidth = (48 * scale) + (7 * cellWidth) + (6 * 16 * scale);
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(width: totalGridWidth, height: constraints.maxHeight, child: grid),
                );
              }
            ),
          ),
        ],
      );
      });
    }
    else if (selectedMenu == 'Друзья') {
      return FriendsScreen(
        currentLang: currentLang,
        scale: scale,
        buildGlassContainer: buildGlassContainer,
        onOpenProfile: (userId) => showUserProfileModal(
          context: context,
          userId: userId,
          currentLang: currentLang,
          onOpenConversation: (partnerId, name) => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ConversationScreen(currentLang: currentLang, partnerId: partnerId, partnerName: name),
          )),
        ),
      );
    }
    else if (selectedMenu == 'Сообщения') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: Text('Сообщения'.tr(currentLang), style: TextStyle(fontFamily: 'Golos Text', fontSize: 22, fontWeight: FontWeight.w700, color: textColor)),
          ),
          Expanded(child: ConversationsListScreen(currentLang: currentLang, scale: scale, buildGlassContainer: buildGlassContainer)),
        ],
      );
    }
    else if (selectedMenu == 'Статистика') {
      return buildStatisticsDashboard();
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

/// Ровно 5 задач на странице ячейки календаря, остальное — постранично
/// (REDESIGN_V3_PLAN.md §5.9: было "криво" из-за нефиксированного числа
/// строк, обрезанных высотой ячейки). Свайп (мышью — через явные
/// dragDevices, тачпад/тач по умолчанию) и стрелки дают одинаковый результат.
class _CalendarDayTasksPager extends StatefulWidget {
  final List<Map<String, dynamic>> tasks;
  final Widget Function(Map<String, dynamic>) buildCalendarTaskCard;
  final double scale;
  final Color dotColor;
  final Color dotColorInactive;

  const _CalendarDayTasksPager({
    required this.tasks,
    required this.buildCalendarTaskCard,
    required this.scale,
    required this.dotColor,
    required this.dotColorInactive,
  });

  @override
  State<_CalendarDayTasksPager> createState() => _CalendarDayTasksPagerState();
}

class _CalendarDayTasksPagerState extends State<_CalendarDayTasksPager> {
  static const int _pageSize = 5;
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _CalendarDayTasksPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    final pageCount = (widget.tasks.length / _pageSize).ceil().clamp(1, 1 << 30);
    if (_page > pageCount - 1) {
      _page = pageCount - 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_controller.hasClients) _controller.jumpToPage(_page);
      });
    }
  }

  void _goTo(int page) {
    _controller.animateToPage(page, duration: ClarifyMotion.base, curve: ClarifyMotion.standard);
  }

  @override
  Widget build(BuildContext context) {
    final pageCount = (widget.tasks.length / _pageSize).ceil().clamp(1, 1 << 30);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ScrollConfiguration(
            behavior: const ScrollBehavior().copyWith(scrollbars: false, dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.trackpad, PointerDeviceKind.stylus}),
            child: PageView.builder(
              controller: _controller,
              itemCount: pageCount,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, pageIndex) {
                final start = pageIndex * _pageSize;
                final end = (start + _pageSize).clamp(0, widget.tasks.length);
                final pageTasks = widget.tasks.sublist(start, end);
                return ListView.builder(
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: pageTasks.length,
                  itemBuilder: (context, i) => widget.buildCalendarTaskCard(pageTasks[i]),
                );
              },
            ),
          ),
        ),
        if (pageCount > 1)
          Padding(
            padding: EdgeInsets.only(top: 2 * widget.scale),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: _page > 0 ? () => _goTo(_page - 1) : null,
                  child: Icon(LucideIcons.chevronLeft, size: 12 * widget.scale, color: _page > 0 ? widget.dotColor : widget.dotColorInactive),
                ),
                ...List.generate(pageCount, (i) => Container(
                      margin: EdgeInsets.symmetric(horizontal: 2 * widget.scale),
                      width: 5 * widget.scale,
                      height: 5 * widget.scale,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: i == _page ? widget.dotColor : widget.dotColorInactive),
                    )),
                GestureDetector(
                  onTap: _page < pageCount - 1 ? () => _goTo(_page + 1) : null,
                  child: Icon(LucideIcons.chevronRight, size: 12 * widget.scale, color: _page < pageCount - 1 ? widget.dotColor : widget.dotColorInactive),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
