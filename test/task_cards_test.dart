import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:frontend/core/theme/design_tokens.dart';
import 'package:frontend/widgets/task_cards.dart';

TaskCardBuilders _builders({
  void Function(Map<String, dynamic>)? onToggle,
  void Function(dynamic)? onDelete,
  void Function(Map<String, dynamic>)? onTap,
  void Function(String)? onTagTap,
}) {
  return TaskCardBuilders(
    isDark: false,
    scale: 1.0,
    currentLang: 'ru',
    workspaceMembers: const {},
    getPriorityColor: (priority) => Colors.grey,
    getSubtaskStats: (parentId) => const {'total': 0, 'done': 0},
    isOverdue: (task) => false,
    onToggle: onToggle ?? (_) {},
    onDelete: onDelete ?? (_) {},
    onTap: onTap ?? (_) {},
    onTagTap: onTagTap ?? (_) {},
    onPriorityTap: (_) {},
    onQuickUpdateTask: (_, _) {},
    buildGlassContainer: ({required child, borderRadius, padding, margin, customColor}) => child,
  );
}

void main() {
  group('TaskCardBuilders.buildListTaskCard', () {
    testWidgets('показывает заголовок задачи', (tester) async {
      final task = {'id': 1, 'title': 'Купить молоко', 'is_completed': false};

      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(extensions: const [ClarifyTokens.light]),
        home: Scaffold(body: _builders().buildListTaskCard(task)),
      ));

      expect(find.text('Купить молоко'), findsOneWidget);
    });

    // С 2026-09-04 крестик виден и кликабелен только под курсором, поэтому
    // тест обязан сперва навести мышь — иначе проверял бы поведение, которого
    // у пользователя нет.
    testWidgets('нажатие на крестик вызывает onDelete с id задачи', (tester) async {
      dynamic deletedId;
      final task = {'id': 42, 'title': 'Задача', 'is_completed': false};

      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(extensions: const [ClarifyTokens.light]),
        home: Scaffold(body: _builders(onDelete: (id) => deletedId = id).buildListTaskCard(task)),
      ));

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.text('Задача')));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(LucideIcons.x));
      await tester.pumpAndSettle();

      expect(deletedId, 42);
    });

    testWidgets('крестик не срабатывает, пока курсор не над строкой', (tester) async {
      dynamic deletedId;
      final task = {'id': 42, 'title': 'Задача', 'is_completed': false};

      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(extensions: const [ClarifyTokens.light]),
        home: Scaffold(body: _builders(onDelete: (id) => deletedId = id).buildListTaskCard(task)),
      ));

      await tester.tap(find.byIcon(LucideIcons.x), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(deletedId, isNull);
    });

    testWidgets('нажатие на зону выполнения вызывает onToggle с самой задачей', (tester) async {
      Map<String, dynamic>? toggled;
      final task = {'id': 1, 'title': 'Задача', 'is_completed': false};

      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(extensions: const [ClarifyTokens.light]),
        home: Scaffold(body: _builders(onToggle: (t) => toggled = t).buildListTaskCard(task)),
      ));
      // Круга-чекбокса в строке больше нет: отмечает зона слева, в которой
      // галочка проявляется при наведении.
      await tester.tap(find.byIcon(LucideIcons.check));
      await tester.pumpAndSettle();

      expect(toggled, task);
    });
  });

  group('TaskCardBuilders.buildCalendarTaskChip', () {
    // Регрессия 2026-08-01: пользователь сообщил, что в ячейке месяца с
    // несколькими задачами видна только пилюля "+N ещё", а сами 3 задачи
    // превью — нет. Виджет-тест этого не подтвердил (все 3 строятся и видны
    // даже в ячейке 60×150 — теснее, чем встречается в реальной сетке), что
    // указывает на проблему деплоя/кэша браузера, а не в самом виджете —
    // но тест остаётся регрессионным стражем на будущее.
    testWidgets('все 3 задачи превью видны в тесной ячейке', (tester) async {
      final builders = _builders();
      final tasks = [
        {'id': 1, 'title': 'Задача Один', 'is_completed': false, 'priority': 'none'},
        {'id': 2, 'title': 'Задача Два', 'is_completed': false, 'priority': 'none'},
        {'id': 3, 'title': 'Задача Три', 'is_completed': false, 'priority': 'none'},
      ];

      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(extensions: [ClarifyTokens.light]),
        home: Scaffold(
          body: SizedBox(
            height: 60,
            width: 150,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [for (final t in tasks) builders.buildCalendarTaskChip(t)],
                  ),
                ),
              ],
            ),
          ),
        ),
      ));
      await tester.pump();

      expect(find.text('Задача Один'), findsOneWidget);
      expect(find.text('Задача Два'), findsOneWidget);
      expect(find.text('Задача Три'), findsOneWidget);
    });

    // Регрессия 2026-08-02: пилюля "+1" накладывалась на текст 3-й задачи,
    // когда строки превью стали двухстрочными (приоритет/бейджи) — высота
    // строки менялась в зависимости от содержимого задачи, из-за чего
    // main_content_area.dart не могла достоверно посчитать, сколько задач
    // реально влезает в ячейку. Фикс — вторая строка ВСЕГДА резервирует
    // высоту (даже пустая), делая высоту строки константной. Этот тест
    // проверяет именно это: задача без бейджей и задача с бейджем/приоритетом
    // должны рендериться с ОДИНАКОВОЙ высотой.
    testWidgets('высота строки одинакова для задачи с бейджами и без', (tester) async {
      final builders = _builders();
      final plainTask = {'id': 1, 'title': 'Простая задача', 'is_completed': false, 'priority': 'none'};
      final richTask = {'id': 2, 'title': 'Задача с приоритетом', 'is_completed': false, 'priority': 'red'};

      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(extensions: [ClarifyTokens.light]),
        home: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              builders.buildCalendarTaskChip(plainTask),
              builders.buildCalendarTaskChip(richTask),
            ],
          ),
        ),
      ));
      await tester.pump();

      final plainHeight = tester.getSize(find.text('Простая задача')).height;
      final richHeight = tester.getSize(find.text('Задача с приоритетом')).height;
      // Сравниваем высоту самих ОБЁРТОК чипов (родитель Column-строки), не
      // текста — у текста высота одна и та же в обоих случаях по построению,
      // это ничего не доказывает про вторую строку.
      final plainChipHeight = tester.getSize(
        find.ancestor(of: find.text('Простая задача'), matching: find.byType(Column)).first,
      ).height;
      final richChipHeight = tester.getSize(
        find.ancestor(of: find.text('Задача с приоритетом'), matching: find.byType(Column)).first,
      ).height;

      expect(plainHeight, greaterThan(0));
      expect(richHeight, greaterThan(0));
      // Это и есть свойство, на которое опирается _CalendarDayTasksPreview
      // (main_content_area.dart): раз высота строки одинакова независимо от
      // содержимого задачи, измерить её по ЛЮБОЙ ОДНОЙ задаче (Offstage-зонд)
      // достаточно, чтобы знать высоту ВСЕХ остальных строк в этой же ячейке.
      expect(plainChipHeight, richChipHeight);
    });
  });
}
