import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/clarify_reorder_flow.dart';

/// Обёртка, позволяющая перестроить ClarifyReorderFlow с другим порядком тех
/// же самых (по ключу) детей — ровно то, что делает список задач, когда
/// отмеченная задача уезжает в блок выполненных.
class _Harness extends StatefulWidget {
  const _Harness();

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  List<String> _order = const ['A', 'B', 'C'];

  void reorder(List<String> next) => setState(() => _order = next);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: ClarifyReorderFlow(
          children: [
            for (final id in _order)
              SizedBox(key: ValueKey(id), height: 40, child: Text(id)),
          ],
        ),
      ),
    );
  }
}

void main() {
  testWidgets('переезд строки: старый порядок держится, пока строка схлопывается', (tester) async {
    await tester.pumpWidget(const _Harness());

    double topOf(String id) => tester.getTopLeft(find.text(id)).dy;
    expect(topOf('A') < topOf('B') && topOf('B') < topOf('C'), isTrue);

    final state = tester.state<_HarnessState>(find.byType(_Harness));
    state.reorder(const ['A', 'C', 'B']);
    await tester.pump();

    // Сразу после перестановки на экране всё ещё прежний порядок: B в этот
    // момент схлопывается на своём старом месте, а не телепортируется вниз.
    expect(find.text('B'), findsOneWidget);
    expect(topOf('B') < topOf('C'), isTrue);

    await tester.pumpAndSettle();

    // После анимации — новый порядок, все строки на месте.
    expect(find.text('B'), findsOneWidget);
    expect(topOf('C') < topOf('B'), isTrue);
  });

  testWidgets('перерисовка с тем же новым порядком не обрывает анимацию', (tester) async {
    // Ровно то, что ломало анимацию на живом приложении: пока строка
    // схлопывается, родитель перестраивает список (ответ сервера,
    // realtime-фетч) — и приносит тот же самый новый порядок. Раньше это
    // принималось за новую перестановку, анимация обрывалась и порядок
    // менялся мгновенно.
    await tester.pumpWidget(const _Harness());
    double topOf(String id) => tester.getTopLeft(find.text(id)).dy;

    final state = tester.state<_HarnessState>(find.byType(_Harness));
    state.reorder(const ['A', 'C', 'B']);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    state.reorder(['A', 'C', 'B']); // новый список, тот же порядок
    await tester.pump();

    // Анимация не оборвана: на экране всё ещё прежний порядок.
    expect(topOf('B') < topOf('C'), isTrue);

    await tester.pumpAndSettle();
    expect(topOf('C') < topOf('B'), isTrue);
  });

  testWidgets('добавление строки принимается сразу, без анимации переезда', (tester) async {
    await tester.pumpWidget(const _Harness());

    final state = tester.state<_HarnessState>(find.byType(_Harness));
    state.reorder(const ['A', 'B', 'C', 'D']);
    await tester.pump();

    expect(find.text('D'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('D'), findsOneWidget);
  });
}
