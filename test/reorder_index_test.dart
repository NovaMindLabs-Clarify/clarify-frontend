import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Семантика onReorderItem (B9: миграция с устаревшего onReorder).
///
/// Разница между колбэками ровно в одном: onReorder отдавал «сырой» newIndex, и
/// обработчик обязан был сам вычесть единицу при движении вниз, а onReorderItem
/// отдаёт индекс уже с учётом вынутого элемента. Если при миграции забыть убрать
/// прежнюю поправку, задача упадёт на позицию ВЫШЕ той, куда её отпустили —
/// заметить это можно только руками, поэтому проверяем тестом.
///
/// Проверяется не конкретное расстояние перетаскивания (оно зависит от того, как
/// ReorderableListView считает перекрытие, и от темпа кадров в тесте), а сам
/// инвариант миграции: ОДИН И ТОТ ЖЕ жест должен давать ОДИН И ТОТ ЖЕ итоговый
/// порядок — и на старом колбэке с ручной поправкой, и на новом без неё. Если
/// поправку забыть убрать, порядки разойдутся.
void main() {
  /// Строит список из четырёх элементов и выполняет одинаковый жест.
  ///
  /// [useLegacy] — старый onReorder с ручной поправкой newIndex (как было в
  /// приложении до миграции), иначе новый onReorderItem без поправки (как стало).
  Future<List<String>> dragAndGetOrder(
    WidgetTester tester, {
    required bool useLegacy,
    required int from,
    required double dy,
  }) async {
    final items = ['A', 'B', 'C', 'D'];

    void legacyHandler(int oldIndex, int newIndex) {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = items.removeAt(oldIndex);
      items.insert(newIndex, item);
    }

    void modernHandler(int oldIndex, int newIndex) {
      final item = items.removeAt(oldIndex);
      items.insert(newIndex, item);
    }

    Widget itemBuilder(BuildContext context, int index) => ReorderableDragStartListener(
          key: ValueKey(items[index]),
          index: index,
          child: SizedBox(height: 100, child: Center(child: Text(items[index]))),
        );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: useLegacy
              // ignore: deprecated_member_use — здесь устаревший колбэк нужен
              // намеренно: тест сравнивает его поведение с новым.
              ? ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  itemCount: items.length,
                  onReorder: legacyHandler,
                  itemBuilder: itemBuilder,
                )
              : ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  itemCount: items.length,
                  onReorderItem: modernHandler,
                  itemBuilder: itemBuilder,
                ),
        ),
      ),
    );

    final gesture = await tester.startGesture(tester.getCenter(find.text(items[from])));
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.moveBy(Offset(0, dy));
    await tester.pumpAndSettle();
    await gesture.up();
    await tester.pumpAndSettle();

    return items;
  }

  for (final (name, from, dy) in <(String, int, double)>[
    ('вниз на одну строку', 0, 120.0),
    ('вниз на две строки', 0, 250.0),
    ('вниз до конца списка', 0, 400.0),
    ('вверх на одну строку', 3, -120.0),
    ('вверх до начала списка', 3, -400.0),
    ('без смещения', 1, 5.0),
  ]) {
    testWidgets('$name: новый колбэк даёт тот же порядок, что старый с поправкой', (tester) async {
      final legacy = await dragAndGetOrder(tester, useLegacy: true, from: from, dy: dy);
      final modern = await dragAndGetOrder(tester, useLegacy: false, from: from, dy: dy);
      expect(modern, legacy);
    });
  }

  testWidgets('жест действительно меняет порядок, иначе сравнение ничего не значит', (tester) async {
    final result = await dragAndGetOrder(tester, useLegacy: false, from: 0, dy: 250);
    expect(result, isNot(['A', 'B', 'C', 'D']));
    expect(result.first, isNot('A'));
  });
}
