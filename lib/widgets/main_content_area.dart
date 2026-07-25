import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/localization.dart';
import '../core/tags.dart';
import '../core/theme/design_tokens.dart';
import 'clarify_glass.dart';
import 'clarify_list_entrance.dart';
import 'clarify_surface.dart';
import 'friends_screen.dart';
import 'messenger_shell.dart';
import 'user_profile_modal.dart';
import 'project_kanban_board.dart';
import 'projects_screen.dart';

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
    this.pendingChatPartnerId,
    this.pendingChatPartnerName,
    this.onOpenDirectChat,
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

      targetTasks.sort((a, b) => (a['due_time'] ?? '23:59').compareTo(b['due_time'] ?? '23:59'));
      if (targetTasks.isEmpty) return Center(child: Text("Пусто. Отдыхаем!".tr(currentLang), style: TextStyle(color: textMuted, fontSize: 18)));

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
                  final t = Curves.easeInOut.transform(animation.value);
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
              return Row(
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
                    final dayTitle = "${_capitalize(weekdaysRu[cellDate.weekday - 1])}, ${dayNumber.toString().padLeft(2, '0')}.${month.toString().padLeft(2, '0')}";
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
                                Expanded(child: _CalendarDayTasksPreview(dayTitle: dayTitle, tasks: dayTasks, buildCalendarTaskCard: buildCalendarTaskCard, buildListTaskCard: buildListTaskCard, scale: scale, t: t, currentLang: currentLang)),
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
          onOpenConversation: (partnerId, name) => onOpenDirectChat?.call(partnerId, name),
        ),
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
