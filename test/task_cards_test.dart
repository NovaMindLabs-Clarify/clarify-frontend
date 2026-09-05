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
  void Function(dynamic, Map<String, dynamic>)? onQuickUpdateTask,
  bool Function(Map<String, dynamic>)? isOverdue,
}) {
  return TaskCardBuilders(
    isDark: false,
    scale: 1.0,
    currentLang: 'ru',
    workspaceMembers: const {},
    getPriorityColor: (priority) => Colors.grey,
    getSubtaskStats: (parentId) => const {'total': 0, 'done': 0},
    isOverdue: isOverdue ?? (task) => false,
    onToggle: onToggle ?? (_) {},
    onDelete: onDelete ?? (_) {},
    onTap: onTap ?? (_) {},
    onTagTap: onTagTap ?? (_) {},
    onPriorityTap: (_) {},
    onQuickUpdateTask: onQuickUpdateTask ?? (_, _) {},
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

    // С 2026-09-04 действия строки видны и кликабельны только под курсором,
    // поэтому тест обязан сперва навести мышь — иначе проверял бы поведение,
    // которого у пользователя нет. С 05.09.2026 крестик заменён группой
    // быстрых действий (D2), удаление — корзина.
    testWidgets('нажатие на кнопку удаления вызывает onDelete с id задачи', (tester) async {
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

      await tester.tap(find.byIcon(LucideIcons.trash2));
      await tester.pumpAndSettle();

      expect(deletedId, 42);
    });

    testWidgets('кнопка удаления не срабатывает, пока курсор не над строкой', (tester) async {
      dynamic deletedId;
      final task = {'id': 42, 'title': 'Задача', 'is_completed': false};

      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(extensions: const [ClarifyTokens.light]),
        home: Scaffold(body: _builders(onDelete: (id) => deletedId = id).buildListTaskCard(task)),
      ));

      await tester.tap(find.byIcon(LucideIcons.trash2), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(deletedId, isNull);
    });

    // D2: вместо одинокого крестика — группа быстрых действий. Смысл в том,
    // что перенос на завтра был самой частой правкой и требовал открытия
    // карточки.
    testWidgets('«На завтра» переносит срок на завтрашнюю дату', (tester) async {
      Map<String, dynamic>? updates;
      final task = {'id': 42, 'title': 'Задача', 'is_completed': false};

      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(extensions: const [ClarifyTokens.light]),
        home: Scaffold(
          body: _builders(onQuickUpdateTask: (_, u) => updates = u).buildListTaskCard(task),
        ),
      ));

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.text('Задача')));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(LucideIcons.arrowRight));
      await tester.pumpAndSettle();

      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final expected = '${tomorrow.day.toString().padLeft(2, '0')}.'
          '${tomorrow.month.toString().padLeft(2, '0')}.${tomorrow.year}';
      expect(updates?['due_date'], expected);
    });

    testWidgets('у выполненной задачи переноса срока нет, только удаление', (tester) async {
      final task = {'id': 42, 'title': 'Готово', 'is_completed': true};

      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(extensions: const [ClarifyTokens.light]),
        home: Scaffold(body: _builders().buildListTaskCard(task)),
      ));

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.text('Готово')));
      await tester.pumpAndSettle();

      expect(find.byIcon(LucideIcons.trash2), findsOneWidget);
      expect(find.byIcon(LucideIcons.arrowRight), findsNothing,
          reason: 'выполненную задачу переносить некуда — у неё нет будущего срока');
    });

    testWidgets('просроченная задача крупнее обычной', (tester) async {
      Future<double> titleSize(bool overdue) async {
        final task = {'id': 1, 'title': 'Задача', 'is_completed': false};
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(extensions: const [ClarifyTokens.light]),
          home: Scaffold(
            body: _builders(isOverdue: (_) => overdue).buildListTaskCard(task),
          ),
        ));
        return tester.widget<Text>(find.text('Задача')).style!.fontSize!;
      }

      final normal = await titleSize(false);
      final overdue = await titleSize(true);
      expect(overdue, greaterThan(normal),
          reason: 'D2: просрочка должна отличаться размером, а не только цветом');
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

    // Живой фидбек 05.09.2026: «всё идёт волной». Дата стояла на своём месте
    // только у задач с одинаковым набором значков — появился у соседа тег, и
    // дата уехала влево. Теперь под каждую сущность зарезервирована колонка,
    // и проверяется именно это: дата на одном и том же месте независимо от
    // того, что идёт справа от неё.
    group('колонки правой части не плавают', () {
      Future<double> dateLeftEdge(
        WidgetTester tester,
        Map<String, dynamic> extra,
      ) async {
        final task = {
          'id': 1,
          'title': 'Задача',
          'is_completed': false,
          'due_date': '02.08.2026',
          'due_time': '16:00',
          ...extra,
        };
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(extensions: const [ClarifyTokens.light]),
          home: Scaffold(
            body: SizedBox(width: 900, child: _builders().buildListTaskCard(task)),
          ),
        ));
        return tester.getTopLeft(find.text('02.08.2026 16:00')).dx;
      }

      testWidgets('тег не сдвигает дату', (tester) async {
        final without = await dateLeftEdge(tester, {});
        final with_ = await dateLeftEdge(tester, {'tags': 'работа'});
        expect(with_, without,
            reason: 'колонка под тег занята всегда, дата не должна двигаться');
      });

      testWidgets('чек-лист не сдвигает дату', (tester) async {
        final without = await dateLeftEdge(tester, {});
        final with_ = await dateLeftEdge(tester, {'checklist': '[{"text":"пункт","done":false}]'});
        expect(with_, without);
      });

      testWidgets('значок повтора не сдвигает дату', (tester) async {
        final without = await dateLeftEdge(tester, {});
        final with_ = await dateLeftEdge(tester, {'recurrence': 'daily'});
        expect(with_, without);
      });

      testWidgets('значок просрочки не сдвигает дату', (tester) async {
        // Просрочка добавляет иконку часов СЛЕВА от даты — без отдельного
        // слота под неё дата у просроченных задач стояла бы правее.
        final task = {
          'id': 1,
          'title': 'Задача',
          'is_completed': false,
          'due_date': '02.08.2026',
          'due_time': '16:00',
        };
        Future<double> edge(bool overdue) async {
          await tester.pumpWidget(MaterialApp(
            theme: ThemeData(extensions: const [ClarifyTokens.light]),
            home: Scaffold(
              body: SizedBox(
                width: 900,
                child: _builders(isOverdue: (_) => overdue).buildListTaskCard(task),
              ),
            ),
          ));
          return tester.getTopLeft(find.text('02.08.2026 16:00')).dx;
        }

        expect(await edge(true), await edge(false));
      });

      testWidgets('длинный тег обрезается, а не растягивает колонку', (tester) async {
        final long = await dateLeftEdge(
          tester,
          {'tags': 'оченьдлинныйтегкоторыйникуданевлезет'},
        );
        final short = await dateLeftEdge(tester, {'tags': 'дом'});
        expect(long, short,
            reason: 'колонка под тег фиксированной ширины: длина тега на неё не влияет');
      });
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
