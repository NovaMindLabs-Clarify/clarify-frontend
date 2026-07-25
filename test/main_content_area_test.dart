import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/main_content_area.dart';

String _fmt(DateTime d) =>
    "${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}";

Widget _harness({
  required String selectedMenu,
  required List<Map<String, dynamic>> tasks,
}) {
  return MaterialApp(
    home: Scaffold(
      body: MainContentArea(
        selectedMenu: selectedMenu,
        currentLang: 'ru',
        filteredTasks: tasks,
        isDark: false,
        scale: 1.0,
        onReorderTasks: (_, _, _) {},
        onTaskDropped: (_, _, _) {},
        onPlusTap: (_, _) {},
        buildListTaskCard: (task) => Text(task['title'] as String),
        buildBoardTaskCardExpanded: (task) => Text(task['title'] as String),
        buildCalendarTaskCard: (task) => Text(task['title'] as String),
        buildGlassContainer: ({required child, margin, padding, customColor}) => child,
        buildStatisticsDashboard: () => const SizedBox.shrink(),
        currentCalendarDate: DateTime.now(),
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
  );
}

void main() {
  final today = DateTime.now();
  final tomorrow = today.add(const Duration(days: 1));

  group('MainContentArea — "Мой день"', () {
    testWidgets('показывает только сегодняшние задачи без родителя', (tester) async {
      final tasks = [
        {'id': 1, 'title': 'Сегодняшняя задача', 'due_date': _fmt(today), 'parent_id': null},
        {'id': 2, 'title': 'Завтрашняя задача', 'due_date': _fmt(tomorrow), 'parent_id': null},
        {'id': 3, 'title': 'Подзадача на сегодня', 'due_date': _fmt(today), 'parent_id': 1},
      ];

      await tester.pumpWidget(_harness(selectedMenu: 'Мой день', tasks: tasks));

      expect(find.text('Сегодняшняя задача'), findsOneWidget);
      expect(find.text('Завтрашняя задача'), findsNothing);
      expect(find.text('Подзадача на сегодня'), findsNothing);
    });

    testWidgets('показывает пустое состояние, если задач на сегодня нет', (tester) async {
      await tester.pumpWidget(_harness(selectedMenu: 'Мой день', tasks: const []));

      expect(find.text('Пусто. Отдыхаем!'), findsOneWidget);
    });
  });

  group('MainContentArea — "Входящие"', () {
    testWidgets('показывает только задачи без даты', (tester) async {
      final tasks = [
        {'id': 1, 'title': 'Без даты', 'due_date': null, 'parent_id': null},
        {'id': 2, 'title': 'С датой', 'due_date': _fmt(today), 'parent_id': null},
      ];

      await tester.pumpWidget(_harness(selectedMenu: 'Входящие', tasks: tasks));

      expect(find.text('Без даты'), findsOneWidget);
      expect(find.text('С датой'), findsNothing);
    });
  });
}
