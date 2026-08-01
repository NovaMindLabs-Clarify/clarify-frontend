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
// MainContentArea с настоящими TaskCardBuilders через реалистичный
// desktop-размер окна (1300×800, явно заданный через tester.view.physicalSize
// — без этого flutter_test молча ограничивает поверхность до 800×600,
// независимо от размеров любых SizedBox внутри, из-за чего этот же тест
// раньше без ведома гонял узкий compact-путь раскладки (<1100px), а не
// обычный десктопный, и однажды поймал ложный провал именно по этой причине).
void main() {
  testWidgets('в ячейке месяца с 3 задачами видны все 3, без переполнения', (tester) async {
    final today = DateTime.now();
    String fmt(DateTime d) => "${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}";
    final tasks = [
      {'id': 1, 'title': 'Задача Один', 'due_date': fmt(today), 'due_time': '09:00', 'parent_id': null, 'is_completed': false, 'priority': 'red'},
      {'id': 2, 'title': 'Задача Два', 'due_date': fmt(today), 'due_time': '14:30', 'parent_id': null, 'is_completed': false, 'priority': 'orange'},
      {'id': 3, 'title': 'Задача Три', 'due_date': fmt(today), 'parent_id': null, 'is_completed': false, 'priority': 'blue'},
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

    // По умолчанию flutter_test использует фиксированную поверхность 800×600
    // независимо от размеров SizedBox внутри — без явной установки
    // tester.view.physicalSize ЛЮБОЙ более широкий/высокий SizedBox всё
    // равно обрезается до 800×600, и тест тихо гоняет узкий (compact,
    // <1100px) путь раскладки сетки вместо обычного десктопного — именно
    // так и было обнаружено ниже (2026-08-01).
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(extensions: [ClarifyTokens.light]),
      home: Scaffold(
        body: SizedBox(
          height: 800,
          width: 1300,
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
