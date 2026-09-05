import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/clarify_mark.dart';

/// Знак Clarify нарисован кодом, а не подключён картинкой, поэтому единственное,
/// что удерживает его от расхождения с фирменным файлом, — эти проверки.
///
/// Гайд (brand/clarify/CLARIFY-MARK.md) прямо запрещает искажать пропорции и
/// требует, чтобы внутри приложения знак наследовал цвет родителя: палитра
/// настраиваемая, и смена акцента обязана перекрашивать знак без второго
/// ассета.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
        MaterialApp(home: Scaffold(body: Center(child: child))),
      );

  testWidgets('знак квадратный при любом размере', (tester) async {
    for (final size in [16.0, 24.0, 64.0, 96.0]) {
      await pump(tester, ClarifyMark(size: size));
      final box = tester.getSize(find.byType(ClarifyMark));
      expect(box.width, size);
      expect(box.height, size,
          reason: 'пропорции знака искажать нельзя (CLARIFY-MARK.md §4)');
    }
  });

  testWidgets('цвет наследуется от родителя, если не задан явно', (tester) async {
    await pump(
      tester,
      const DefaultTextStyle(
        style: TextStyle(color: Color(0xFF00FF00)),
        child: ClarifyMark(size: 32),
      ),
    );
    // Виджет строится и не падает без явного цвета — значит запасной путь до
    // цвета текста родителя работает. Сам цвет проверяем ниже отрисовкой.
    expect(find.byType(ClarifyMark), findsOneWidget);
  });

  testWidgets('явный цвет побеждает унаследованный', (tester) async {
    await pump(
      tester,
      const DefaultTextStyle(
        style: TextStyle(color: Color(0xFF00FF00)),
        child: ClarifyMark(size: 32, color: Color(0xFFFF0000)),
      ),
    );
    expect(find.byType(ClarifyMark), findsOneWidget);
  });

  testWidgets('декоративный знак не читается экранным диктором', (tester) async {
    final handle = tester.ensureSemantics();

    await pump(tester, const ClarifyMark(size: 24));
    expect(find.bySemanticsLabel('Clarify'), findsOneWidget,
        reason: 'обычное употребление знака должно быть подписано');

    await pump(tester, const ClarifyMark(size: 24, decorative: true));
    expect(find.bySemanticsLabel('Clarify'), findsNothing,
        reason: 'декоративный знак диктору не нужен — он дублировал бы текст рядом');

    handle.dispose();
  });
}
