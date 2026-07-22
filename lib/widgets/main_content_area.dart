import 'package:flutter/material.dart';
import '../core/localization.dart';
import '../core/theme/design_tokens.dart';

class MainContentArea extends StatelessWidget {
  final String selectedMenu;
  final String currentLang;
  final List<String> customFolders;
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
  
  // Дата календаря передается как состояние
  final DateTime currentCalendarDate;
  final Function(DateTime) onCalendarDateChanged;

  const MainContentArea({
    Key? key,
    required this.selectedMenu,
    required this.currentLang,
    required this.customFolders,
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

    if (selectedMenu == 'Все задачи' || selectedMenu == 'Мой день' || selectedMenu == 'Входящие' || customFolders.contains(selectedMenu) || selectedMenu.startsWith('ws_')) {
      List<Map<String, dynamic>> targetTasks = filteredTasks;
      
      if (selectedMenu == 'Мой день') {
        final todayStr = _formatDate(DateTime.now()); 
        targetTasks = filteredTasks.where((t) => t['due_date'] == todayStr && t['parent_id'] == null).toList();
      } else if (selectedMenu == 'Входящие') {
        targetTasks = filteredTasks.where((t) => (t['due_date'] == null || t['due_date'] == '') && t['parent_id'] == null).toList();
      } else if (customFolders.contains(selectedMenu)) {
        targetTasks = filteredTasks.where((t) => t['folder'] == selectedMenu && t['parent_id'] == null).toList();
      } else if (selectedMenu.startsWith('ws_')) {
        int wsId = int.parse(selectedMenu.substring(3));
        targetTasks = filteredTasks.where((t) => t['workspace_id'] == wsId && t['parent_id'] == null).toList();
      } else { 
        targetTasks = filteredTasks.where((t) => t['parent_id'] == null).toList(); 
      }
      
      targetTasks.sort((a, b) => (a['due_time'] ?? '23:59').compareTo(b['due_time'] ?? '23:59'));
      if (targetTasks.isEmpty) return Center(child: Text("Пусто. Отдыхаем!".tr(currentLang), style: TextStyle(color: textMuted, fontSize: 18)));
      
      if (selectedMenu == 'Мой день' || customFolders.contains(selectedMenu)) {
        return ReorderableListView(
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
        );
      } else {
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24), 
          children: targetTasks.map((task) { 
            return LongPressDraggable<Map<String, dynamic>>(
              data: task, delay: const Duration(milliseconds: 200), 
              feedback: Material(color: Colors.transparent, child: SizedBox(width: 500, child: buildListTaskCard(task))), 
              childWhenDragging: Opacity(opacity: 0.3, child: buildListTaskCard(task)), child: buildListTaskCard(task)
            ); 
          }).toList()
        );
      } 
    }
    else if (selectedMenu == 'Следующие 7 дней') {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 8 * scale),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: List.generate(7, (index) {
            final targetDate = DateTime.now().add(Duration(days: index)); 
            final dateStr = _formatDate(targetDate);
            final dayTasks = filteredTasks.where((t) => t['due_date'] == dateStr && t['parent_id'] == null).toList();
            dayTasks.sort((a, b) => (a['due_time'] ?? '23:59').compareTo(b['due_time'] ?? '23:59'));
            
            final weekdayName = _capitalize(weekdaysRu[targetDate.weekday - 1]);
            String title = index == 0 ? 'Сегодня'.tr(currentLang) : (index == 1 ? 'Завтра'.tr(currentLang) : weekdayName);
            String subtitle = index < 2 ? weekdayName : "${targetDate.day.toString().padLeft(2, '0')}.${targetDate.month.toString().padLeft(2, '0')}";
            
            return Expanded(
              child: DragTarget<Map<String, dynamic>>(
                onAccept: (Map<String, dynamic> task) => onTaskDropped(task, dateStr, dayTasks.length),
                builder: (context, candidateData, rejectedData) {
                  return buildGlassContainer(
                    margin: EdgeInsets.only(right: index == 6 ? 0 : 12 * scale),
                    customColor: candidateData.isNotEmpty ? highlightColor : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(padding: EdgeInsets.fromLTRB(16 * scale, 20 * scale, 16 * scale, 12 * scale), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title.tr(currentLang), style: TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.bold, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis), SizedBox(height: 4 * scale), Text(subtitle.tr(currentLang), style: TextStyle(fontSize: 13 * scale, color: textMuted, fontWeight: FontWeight.w600))])),
                        Padding(padding: EdgeInsets.fromLTRB(12 * scale, 0, 12 * scale, 16 * scale), child: InkWell(borderRadius: BorderRadius.circular(12 * scale), onTap: () => onPlusTap(targetDate, dayTasks.length), child: Container(width: double.infinity, padding: EdgeInsets.symmetric(vertical: 6 * scale), decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(12 * scale), border: Border.all(color: glassBorderColor, width: 1.0)), child: Icon(Icons.add, size: 16 * scale, color: textMuted)), ), ),
                        Expanded(child: ListView.builder(padding: EdgeInsets.symmetric(horizontal: 12 * scale), itemCount: dayTasks.length, itemBuilder: (context, taskIndex) { final task = dayTasks[taskIndex]; return LongPressDraggable<Map<String, dynamic>>(data: task, delay: const Duration(milliseconds: 200), feedback: Material(color: Colors.transparent, child: SizedBox(width: 250 * scale, child: buildBoardTaskCardExpanded(task))), childWhenDragging: Opacity(opacity: 0.3, child: buildBoardTaskCardExpanded(task)), child: buildBoardTaskCardExpanded(task)); }), ),
                      ],
                    ),
                  );
                },
              ),
            );
          }),
        ),
      );
    }
    else if (selectedMenu == 'Календарь') {
      final year = currentCalendarDate.year; final month = currentCalendarDate.month;
      final firstDayOfMonth = DateTime(year, month, 1); final lastDayOfMonth = DateTime(year, month + 1, 0);
      final int startOffset = firstDayOfMonth.weekday - 1; final int totalDaysInMonth = lastDayOfMonth.day; final int totalCells = startOffset + totalDaysInMonth;
      final List<String> monthsRu = ['', 'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь', 'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'];

      return Column(
        children: [
          Padding(padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 12 * scale), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("${monthsRu[month].tr(currentLang)} $year", style: TextStyle(fontSize: 24 * scale, fontWeight: FontWeight.bold, color: textColor)), Row(children: [IconButton(icon: Icon(Icons.chevron_left, color: textColor, size: 28 * scale), onPressed: () => onCalendarDateChanged(DateTime(year, month - 1))), IconButton(icon: Icon(Icons.chevron_right, color: textColor, size: 28 * scale), onPressed: () => onCalendarDateChanged(DateTime(year, month + 1))), ], )], ), ),
          Padding(padding: EdgeInsets.symmetric(horizontal: 24 * scale), child: Row(children: ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'].map((day) => Expanded(child: Center(child: Text(day.tr(currentLang), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16 * scale, color: textMuted))))).toList(),),),
          SizedBox(height: 12 * scale),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final int rows = (totalCells / 7).ceil(); 
                final double cellWidth = (constraints.maxWidth - (48 * scale) - (16 * scale * 6)) / 7; 
                final double cellHeight = (constraints.maxHeight - (48 * scale) - (16 * scale * (rows - 1))) / rows; 
                final double childAspectRatio = (cellWidth > 0 && cellHeight > 0) ? (cellWidth / cellHeight) : 1.0;
                
                return GridView.builder(
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
                              Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: ScrollConfiguration(behavior: const ScrollBehavior().copyWith(scrollbars: false), child: ListView.builder(padding: EdgeInsets.zero, itemCount: dayTasks.length, itemBuilder: (context, taskIndex) => buildCalendarTaskCard(dayTasks[taskIndex])), ), ), Align(alignment: Alignment.bottomCenter, child: InkWell(onTap: () => onPlusTap(cellDate, taskCount), child: Padding(padding: EdgeInsets.only(bottom: 4 * scale), child: Icon(Icons.add, color: textMuted, size: 20 * scale), ), ), )], ), ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              }
            ),
          ),
        ],
      );
    }
    else if (selectedMenu == 'Статистика') {
      return buildStatisticsDashboard();
    }
    return const SizedBox.shrink();
  }
} 