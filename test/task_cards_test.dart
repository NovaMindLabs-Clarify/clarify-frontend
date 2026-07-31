import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:frontend/widgets/clarify_task_checkbox.dart';
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
    buildGlassContainer: ({required child, borderRadius, padding, margin, customColor}) => child,
  );
}

void main() {
  group('TaskCardBuilders.buildListTaskCard', () {
    testWidgets('показывает заголовок задачи', (tester) async {
      final task = {'id': 1, 'title': 'Купить молоко', 'is_completed': false};

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: _builders().buildListTaskCard(task))));

      expect(find.text('Купить молоко'), findsOneWidget);
    });

    testWidgets('нажатие на крестик вызывает onDelete с id задачи', (tester) async {
      dynamic deletedId;
      final task = {'id': 42, 'title': 'Задача', 'is_completed': false};

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: _builders(onDelete: (id) => deletedId = id).buildListTaskCard(task)),
      ));
      await tester.tap(find.byIcon(LucideIcons.x));
      await tester.pumpAndSettle();

      expect(deletedId, 42);
    });

    testWidgets('переключение чекбокса вызывает onToggle с самой задачей', (tester) async {
      Map<String, dynamic>? toggled;
      final task = {'id': 1, 'title': 'Задача', 'is_completed': false};

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: _builders(onToggle: (t) => toggled = t).buildListTaskCard(task)),
      ));
      await tester.tap(find.byType(ClarifyCheckCircle));

      expect(toggled, task);
    });
  });
}
