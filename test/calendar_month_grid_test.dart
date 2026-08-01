import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/design_tokens.dart';
import 'package:frontend/widgets/clarify_glass.dart';
import 'package:frontend/widgets/main_content_area.dart';
import 'package:frontend/widgets/task_cards.dart';

// Регрессия 2026-08-01: живой отчёт пользователя — в ячейке дня с 2 задачами
// видна только 1 (без переполнения!), в ячейке с 5 видно 0 + "+2 Ещё".
// Причина: заголовок числа дня + кнопка "+" каждый занимали свою строку в
// Column и вместе съедали почти всю высоту ячейки, не оставляя места под
// список превью — на любом сколько-нибудь тесном экране. Кнопка "+" теперь
// наложена поверх контента (Stack), а не занимает отдельную строку; сетка и
// сама ячейка используют минимальные отступы. Этот тест гоняет ПОЛНУЮ
// MainContentArea с настоящими TaskCardBuilders через реалистичную высоту
// окна (600px content area — после потери на шапку страницы это соответствует
// плюс-минус обычному ноутбучному окну браузера).
void main() {
  testWidgets('в ячейке месяца с 3 задачами видны все 3, без переполнения', (tester) async {
    final today = DateTime.now();
    String fmt(DateTime d) => "${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}";
    final tasks = [
      {'id': 1, 'title': 'Задача Один', 'due_date': fmt(today), 'due_time': '09:00', 'parent_id': null, 'is_completed': false, 'priority': 'none'},
      {'id': 2, 'title': 'Задача Два', 'due_date': fmt(today), 'due_time': '14:30', 'parent_id': null, 'is_completed': false, 'priority': 'none'},
      {'id': 3, 'title': 'Задача Три', 'due_date': fmt(today), 'parent_id': null, 'is_completed': false, 'priority': 'none'},
    ];

    final builders = TaskCardBuilders(
      isDark: false,
      scale: 1.0,
      currentLang: 'ru',
      workspaceMembers: const {},
      getPriorityColor: (priority) => Colors.grey,
      getSubtaskStats: (parentId) => const {'total': 0, 'done': 0},
      isOverdue: (task) => false,
      onToggle: (_) {},
      onDelete: (_) {},
      onTap: (_) {},
      onTagTap: (_) {},
      onPriorityTap: (_) {},
      onQuickUpdateTask: (_, _) {},
      buildGlassContainer: ({required child, borderRadius, padding, margin, customColor}) => child,
    );

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(extensions: [ClarifyTokens.light]),
      home: Scaffold(
        body: SizedBox(
          height: 600,
          width: 900,
          child: MainContentArea(
            selectedMenu: 'Календарь',
            currentLang: 'ru',
            filteredTasks: tasks,
            isDark: false,
            scale: 1.0,
            onReorderTasks: (_, _, _) {},
            onTaskDropped: (_, _, _) {},
            onPlusTap: (_, _) {},
            buildListTaskCard: builders.buildListTaskCard,
            buildBoardTaskCardExpanded: builders.buildBoardTaskCardExpanded,
            buildCalendarTaskCard: builders.buildCalendarTaskCard,
            buildCalendarTaskChip: builders.buildCalendarTaskChip,
            buildGlassContainer: ({required child, margin, padding, customColor}) =>
                ClarifyGlass(margin: margin, padding: padding, customColor: customColor, child: child),
            buildStatisticsDashboard: () => const SizedBox.shrink(),
            buildSettingsPanel: () => const SizedBox.shrink(),
            currentCalendarDate: today,
            onCalendarDateChanged: (_) {},
            getLocalKanbanStatus: (_) => 'todo',
            onSetLocalKanbanStatus: (_, _) {},
            onMenuSelected: (_) {},
            projectIconKeys: const {},
            onSetProjectIcon: (_, _) {},
            projectColorKeys: const {},
            onSetProjectColor: (_, _) {},
            sortByPriority: false,
            onToggleSortByPriority: () {},
          ),
        ),
      ),
    ));
    await tester.pump();

    expect(find.text('Задача Один'), findsOneWidget);
    expect(find.text('Задача Два'), findsOneWidget);
    expect(find.text('Задача Три'), findsOneWidget);
    // Время задачи (2026-08-01, фидбог "добавь информативности") — короткое
    // и предсказуемое по ширине, не рискует вытолкнуть третью строку.
    expect(find.text('09:00'), findsOneWidget);
    expect(find.text('14:30'), findsOneWidget);
  });
}
