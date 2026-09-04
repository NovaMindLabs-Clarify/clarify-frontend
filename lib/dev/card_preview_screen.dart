import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/theme/design_tokens.dart';

/// ВРЕМЕННЫЙ экран для выбора вида строки задачи. Открывается только запуском
/// с аргументом `--card-preview` и ни из какого места интерфейса не доступен.
/// Когда вид выбран — этот файл и ветка в main.dart удаляются целиком.
///
/// Здесь сознательно НЕ переиспользуются TaskCardBuilders: смысл превью в том,
/// чтобы сравнить принципиально разные подходы к строке, а не разные настройки
/// одного и того же. Данные — реалистичный набор задач, покрывающий все
/// состояния (просрочка, гниение, переносы, чек-лист, выполненная, без даты).

class PreviewTask {
  final String title;
  final String? time;
  final String? tag;
  final String priority; // none | blue | orange | red
  final bool done;
  final bool overdue;
  final int rotDays;
  final int rescheduled;
  final int checklistDone;
  final int checklistTotal;
  final int durationMinutes;

  const PreviewTask({
    required this.title,
    this.time,
    this.tag,
    this.priority = 'none',
    this.done = false,
    this.overdue = false,
    this.rotDays = 0,
    this.rescheduled = 0,
    this.checklistDone = 0,
    this.checklistTotal = 0,
    this.durationMinutes = 0,
  });
}

const demoTasks = <PreviewTask>[
  PreviewTask(
    title: 'Отправить смету по объекту на Приморской',
    time: '09:30',
    tag: 'работа',
    priority: 'red',
    overdue: true,
    rescheduled: 5,
    durationMinutes: 45,
  ),
  PreviewTask(
    title: 'Созвон с подрядчиком по кабелю 35 кВ',
    time: '11:00',
    tag: 'работа',
    priority: 'orange',
    durationMinutes: 60,
  ),
  PreviewTask(
    title: 'Разобрать почту и выставить счета',
    time: '13:00',
    tag: 'работа',
    checklistDone: 2,
    checklistTotal: 5,
    durationMinutes: 90,
  ),
  PreviewTask(
    title: 'Забрать документы из БТИ',
    time: '16:00',
    tag: 'личное',
    priority: 'blue',
    durationMinutes: 30,
  ),
  PreviewTask(
    title: 'Продлить страховку на машину',
    tag: 'личное',
    rotDays: 12,
  ),
  PreviewTask(
    title: 'Придумать название для новой функции',
    rotDays: 6,
  ),
  PreviewTask(
    title: 'Купить корм коту',
    tag: 'дом',
    time: '19:00',
    durationMinutes: 15,
  ),
  PreviewTask(
    title: 'Записаться к стоматологу',
    tag: 'здоровье',
    rescheduled: 3,
  ),
  PreviewTask(title: 'Оплатить домен clarify.app', time: '08:00', done: true),
  PreviewTask(title: 'Сделать бэкап проекта', done: true, tag: 'работа'),
];

Color _priorityColor(ClarifyTokens t, String priority) {
  switch (priority) {
    case 'red':
      return t.danger;
    case 'orange':
      return t.warning;
    case 'blue':
      return t.accent;
    default:
      return t.text3;
  }
}

class CardPreviewScreen extends StatefulWidget {
  const CardPreviewScreen({super.key});

  @override
  State<CardPreviewScreen> createState() => _CardPreviewScreenState();
}

class _CardPreviewScreenState extends State<CardPreviewScreen> {
  int _variant = 0;

  static const _titles = [
    'Вариант 1 — Документ',
    'Вариант 2 — Состояние',
    'Вариант 3 — День на оси',
    'Вариант 4 — Гибрид, ПК и телефон',
    'Вариант 5 — Своё лицо',
    'Вариант 6 — Без круга: жест и наведение',
  ];
  static const _subtitles = [
    'Нет рамок и подложек. Иерархию держит только типографика, строка занимает 40px вместо 90.',
    'Вид строки задаёт её состояние: просрочка, гниение, переносы. Список читается как картина дел.',
    'Задачи стоят на реальном времени. Пустые окна и перегруженные часы видно глазом.',
    'Одна и та же строка в двух плотностях: слева ПК, справа телефон в реальной ширине 390px.',
    'Та же анатомия, но без индиго и с днём как ёмкостью. Цвет только там, где он что-то значит.',
    'Кружка нет. На ПК зона выполнения слева проявляется при наведении, на телефоне — свайп.',
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // Пятый вариант живёт в своей палитре — иначе его не с чем сравнивать:
    // весь смысл в том, что уходим от индиго и тёмно-синей базы.
    if (_variant == 4 || _variant == 5) {
      return Scaffold(
        backgroundColor: _Ink.bg,
        body: Column(
          children: [
            _switcher(t, onInk: true),
            Expanded(child: _variant == 4 ? const _VariantOwnFace() : const _VariantGesture()),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          _switcher(t),
          Expanded(
            child: _variant == 3
                ? const _VariantHybrid()
                : Center(
                    child: SizedBox(
                      width: 760,
                      child: switch (_variant) {
                        0 => const _VariantDocument(),
                        1 => const _VariantState(),
                        _ => const _VariantTimeline(),
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _switcher(ClarifyTokens t, {bool onInk = false}) {
    final titleColor = onInk ? _Ink.text : t.text;
    final mutedColor = onInk ? _Ink.text3 : t.text3;
    final borderColor = onInk ? _Ink.border : t.border;
    final activeColor = onInk ? _Ink.text : t.accent;
    final activeText = onInk ? _Ink.bg : t.onAccent;

    return Container(
      padding: const EdgeInsets.fromLTRB(40, 28, 40, 20),
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _titles[_variant],
                style: TextStyle(
                  fontFamily: 'Unbounded',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              for (var i = 0; i < 6; i++)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _variant = i),
                    child: Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _variant == i ? activeColor : Colors.transparent,
                        border: Border.all(color: _variant == i ? activeColor : borderColor),
                        borderRadius: BorderRadius.circular(ClarifyRadius.sm),
                      ),
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          color: _variant == i ? activeText : mutedColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(_subtitles[_variant], style: TextStyle(color: mutedColor, fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Вариант 1 — «Документ»
// ---------------------------------------------------------------------------

class _VariantDocument extends StatelessWidget {
  const _VariantDocument();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final active = demoTasks.where((task) => !task.done).toList();
    final done = demoTasks.where((task) => task.done).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      children: [
        _section(t, 'Сегодня', '${active.length} задач · 4 ч 20 мин'),
        for (final task in active) _row(t, task),
        const SizedBox(height: 28),
        _section(t, 'Выполнено', '${done.length}'),
        for (final task in done) _row(t, task),
      ],
    );
  }

  Widget _section(ClarifyTokens t, String title, String meta) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Unbounded',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: t.text,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(width: 10),
          Text(meta, style: TextStyle(color: t.text3, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _row(ClarifyTokens t, PreviewTask task) {
    final color = _priorityColor(t, task.priority);
    return Container(
      height: 40,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.border.withValues(alpha: 0.55))),
      ),
      child: Row(
        children: [
          // Кружок выполнения — обводка тонкая, 16px: в плотном списке
          // 22-пиксельный кружок начинает доминировать над самим текстом.
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: task.done ? t.accent : Colors.transparent,
              border: Border.all(
                color: task.done ? t.accent : (task.priority == 'none' ? t.borderStrong : color),
                width: 1.4,
              ),
            ),
            child: task.done ? const Icon(LucideIcons.check, size: 10, color: Colors.white) : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              task.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.2,
                fontWeight: task.overdue ? FontWeight.w600 : FontWeight.w500,
                color: task.done ? t.text3 : (task.overdue ? t.danger : t.text),
                decoration: task.done ? TextDecoration.lineThrough : null,
                decorationColor: t.text3,
              ),
            ),
          ),
          if (task.checklistTotal > 0) ...[
            Text(
              '${task.checklistDone}/${task.checklistTotal}',
              style: TextStyle(color: t.text3, fontSize: 12, fontFeatures: const [FontFeature.tabularFigures()]),
            ),
            const SizedBox(width: 14),
          ],
          if (task.tag != null) ...[
            Text('#${task.tag}', style: TextStyle(color: t.text3, fontSize: 12.5)),
            const SizedBox(width: 14),
          ],
          SizedBox(
            width: 44,
            child: Text(
              task.time ?? '',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: task.overdue ? t.danger : t.text2,
                fontSize: 12.5,
                fontWeight: task.overdue ? FontWeight.w700 : FontWeight.w500,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Вариант 2 — «Состояние»
// ---------------------------------------------------------------------------

class _VariantState extends StatelessWidget {
  const _VariantState();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ListView(
      padding: const EdgeInsets.fromLTRB(40, 0, 40, 40),
      children: [for (final task in demoTasks) _row(t, task)],
    );
  }

  Widget _row(ClarifyTokens t, PreviewTask task) {
    // Вес строки задаётся состоянием, а не оформлением: просроченная тяжелее
    // обычной, гниющая — легче и глуше, выполненная почти растворяется.
    final bool urgent = task.overdue;
    final bool rotting = task.rotDays >= 5 && !task.done;
    final double titleSize = urgent ? 17 : (task.priority == 'red' || task.priority == 'orange' ? 15.5 : 14.5);
    final Color titleColor = task.done
        ? t.text3
        : urgent
            ? t.text
            : rotting
                ? t.text2
                : t.text;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Container(
        padding: EdgeInsets.fromLTRB(14, urgent ? 14 : 9, 14, urgent ? 14 : 9),
        decoration: BoxDecoration(
          // Приоритет и срочность — мягкой заливкой слева направо, а не
          // двухпиксельной полоской, которую на тёмной теме почти не видно.
          gradient: urgent
              ? LinearGradient(
                  colors: [t.danger.withValues(alpha: 0.16), t.danger.withValues(alpha: 0.0)],
                  stops: const [0, 0.55],
                )
              : task.priority != 'none' && !task.done
                  ? LinearGradient(
                      colors: [
                        _priorityColor(t, task.priority).withValues(alpha: 0.10),
                        _priorityColor(t, task.priority).withValues(alpha: 0.0),
                      ],
                      stops: const [0, 0.4],
                    )
                  : null,
          border: Border(
            left: BorderSide(
              color: task.done
                  ? Colors.transparent
                  : urgent
                      ? t.danger
                      : task.priority != 'none'
                          ? _priorityColor(t, task.priority)
                          : Colors.transparent,
              width: urgent ? 3 : 2,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: urgent ? 20 : 17,
              height: urgent ? 20 : 17,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: task.done ? t.accent : Colors.transparent,
                border: Border.all(
                  color: task.done ? t.accent : (urgent ? t.danger : t.borderStrong),
                  width: 1.5,
                ),
              ),
              child: task.done ? const Icon(LucideIcons.check, size: 11, color: Colors.white) : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: titleSize,
                      height: 1.25,
                      fontWeight: urgent ? FontWeight.w700 : FontWeight.w600,
                      color: titleColor,
                      decoration: task.done ? TextDecoration.lineThrough : null,
                      decorationColor: t.text3,
                    ),
                  ),
                  if (urgent || rotting || task.rescheduled >= 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          if (urgent)
                            _signal(t, LucideIcons.clockAlert, 'просрочено', t.danger),
                          if (task.rescheduled >= 3)
                            _signal(t, LucideIcons.arrowRight, 'переносили ${task.rescheduled} раз', t.warning),
                          if (rotting)
                            _signal(t, LucideIcons.hourglass, 'лежит ${task.rotDays} дней', t.text3),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (task.time != null)
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  task.time!,
                  style: TextStyle(
                    color: urgent ? t.danger : t.text2,
                    fontSize: 13,
                    fontWeight: urgent ? FontWeight.w700 : FontWeight.w500,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _signal(ClarifyTokens t, IconData icon, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Вариант 5 — «Своё лицо»: другая палитра + день как ёмкость
// ---------------------------------------------------------------------------

/// Палитра без индиго. Тёплая графитовая база вместо сине-чёрной и —
/// главное — **никакого фирменного акцента в оформлении**. Цвет появляется
/// только там, где несёт смысл: просрочка, перенос, выполнено. Кнопки,
/// выделение и активные состояния делаются контрастом и типографикой.
///
/// Причина: тёмно-синий фон плюс акцент 4F46E5 (это дефолтный индиго Tailwind)
/// плюс скруглённые блоки — ровно та триада, которая опознаётся как «собрано
/// нейросетью» раньше, чем человек успевает прочитать содержимое. Уйти от неё
/// дешевле и эффективнее, чем переделывать анатомию строки.
class _Ink {
  _Ink._();

  static const bg = Color(0xFF15130F);
  static const border = Color(0x1AF2EDE3);
  static const borderStrong = Color(0x33F2EDE3);

  static const text = Color(0xFFF2EDE3);
  static const text2 = Color(0xFFA9A093);
  static const text3 = Color(0xFF736B60);

  // Смысловые цвета — единственные цветные пятна в интерфейсе.
  static const overdue = Color(0xFFE0614C);
  static const moved = Color(0xFFD9A441);
  static const done = Color(0xFF8A9A6B);
}

class _VariantOwnFace extends StatelessWidget {
  const _VariantOwnFace();

  @override
  Widget build(BuildContext context) {
    final active = demoTasks.where((task) => !task.done).toList();
    final done = demoTasks.where((task) => task.done).toList();
    final plannedMinutes = demoTasks.where((t) => !t.done).fold<int>(0, (sum, t) => sum + t.durationMinutes);

    return Center(
      child: SizedBox(
        width: 720,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            _DayCapacityHeader(plannedMinutes: plannedMinutes, capacityMinutes: 360),
            const SizedBox(height: 22),
            for (final task in active) _InkRow(task: task),
            const SizedBox(height: 26),
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 8),
              child: Text(
                'ЗАКРЫТО СЕГОДНЯ — ${done.length}',
                style: const TextStyle(
                  color: _Ink.text3,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
            ),
            for (final task in done) _InkRow(task: task),
          ],
        ),
      ),
    );
  }
}

/// День как ёмкость, а не как перечень. Ни у Todoist, ни у TickTick, ни у
/// Things такого нет: они показывают, СКОЛЬКО задач, но не сколько от дня
/// осталось. У нас длительность задач уже есть — значит есть и ответ.
class _DayCapacityHeader extends StatelessWidget {
  final int plannedMinutes;
  final int capacityMinutes;

  const _DayCapacityHeader({required this.plannedMinutes, required this.capacityMinutes});

  String _human(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '$m мин';
    if (m == 0) return '$h ч';
    return '$h ч $m мин';
  }

  @override
  Widget build(BuildContext context) {
    final ratio = (plannedMinutes / capacityMinutes).clamp(0.0, 1.4);
    final overloaded = ratio > 1.0;
    final tight = ratio > 0.8;
    final barColor = overloaded ? _Ink.overdue : (tight ? _Ink.moved : _Ink.text2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            const Text(
              'Четверг, 4 сентября',
              style: TextStyle(
                fontFamily: 'Unbounded',
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: _Ink.text,
                letterSpacing: -0.4,
              ),
            ),
            const Spacer(),
            Text(
              '${_human(plannedMinutes)} из ${_human(capacityMinutes)}',
              style: TextStyle(
                color: overloaded ? _Ink.overdue : _Ink.text2,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Полоса ёмкости дня: занятое время против разумного предела. Пустой
        // хвост справа — это и есть «сколько ещё влезет», ответ на вопрос,
        // который человек задаёт себе каждый раз, когда планирует день.
        LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: _Ink.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Container(
                  height: 4,
                  width: constraints.maxWidth * (ratio > 1 ? 1 : ratio),
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            );
          },
        ),
        if (tight) ...[
          const SizedBox(height: 8),
          Text(
            overloaded
                ? 'День перегружен — что-то стоит перенести'
                : 'День почти забит, свободно чуть больше часа',
            style: TextStyle(color: barColor, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }
}

class _InkRow extends StatelessWidget {
  final PreviewTask task;

  const _InkRow({required this.task});

  @override
  Widget build(BuildContext context) {
    final bool urgent = task.overdue && !task.done;
    final bool rotting = task.rotDays >= 5 && !task.done;
    final bool moved = task.rescheduled >= 3 && !task.done;

    return Container(
      constraints: const BoxConstraints(minHeight: 46),
      padding: const EdgeInsets.fromLTRB(2, 9, 2, 9),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _Ink.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Чекбокс без заливки акцентом: выполненная задача гасится оливковым,
          // а не фирменным цветом — фирменного цвета в оформлении больше нет.
          Container(
            width: 17,
            height: 17,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: task.done ? _Ink.done : Colors.transparent,
              border: Border.all(
                color: task.done
                    ? _Ink.done
                    : urgent
                        ? _Ink.overdue
                        : _Ink.borderStrong,
                width: 1.4,
              ),
            ),
            child: task.done ? const Icon(LucideIcons.check, size: 10, color: _Ink.bg) : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.25,
                    fontWeight: urgent ? FontWeight.w700 : FontWeight.w500,
                    color: task.done ? _Ink.text3 : (rotting ? _Ink.text2 : _Ink.text),
                    decoration: task.done ? TextDecoration.lineThrough : null,
                    decorationColor: _Ink.text3,
                  ),
                ),
                if (urgent || rotting || moved)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        if (urgent) _mark('просрочено на 2 дня', _Ink.overdue),
                        if (moved) _mark('переносили ${task.rescheduled} раз', _Ink.moved),
                        if (rotting) _mark('лежит без движения ${task.rotDays} дней', _Ink.text3),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (task.durationMinutes > 0 && !task.done) ...[
            const SizedBox(width: 12),
            Text(
              '${task.durationMinutes} мин',
              style: const TextStyle(color: _Ink.text3, fontSize: 12),
            ),
          ],
          if (task.time != null) ...[
            const SizedBox(width: 14),
            SizedBox(
              width: 42,
              child: Text(
                task.time!,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: urgent ? _Ink.overdue : _Ink.text2,
                  fontSize: 12.5,
                  fontWeight: urgent ? FontWeight.w700 : FontWeight.w500,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Сигнал состояния — словами, а не значком. Значок надо расшифровывать,
  /// фраза читается сразу; именно это и есть то, чего нет у конкурентов.
  Widget _mark(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 4, height: 4, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Вариант 6 — без кружка: наведение на ПК, свайп на телефоне
// ---------------------------------------------------------------------------

/// Компромисс по живому предложению «убрать круг, отмечать свайпом».
///
/// Что взято из предложения: круга в списке нет, на телефоне свайп вправо
/// отмечает выполненной, подсказка на первой задаче при первом заходе.
///
/// Что изменено и почему:
/// - на десктопе свайпа не существует, а «зажать и протащить» у нас уже занято
///   переносом задачи между днями и в календарь — один жест с двумя смыслами
///   гарантированно приводит к тому, что задача отмечается вместо переноса.
///   Поэтому на ПК вместо круга — зона выполнения по левой кромке строки:
///   при наведении в ней проявляется галочка, клик закрывает задачу;
/// - свайп влево НЕ удаляет сразу, а открывает две кнопки. Удаление у нас
///   необратимое (корзины нет), ставить его на жест рядом с самым частым
///   действием — заявка на случайные потери;
/// - у обоих действий есть отмена плашкой на несколько секунд.
class _VariantGesture extends StatelessWidget {
  const _VariantGesture();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(40, 0, 40, 40),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _caption('ПК — КРУГА НЕТ, ЗОНА ВЫПОЛНЕНИЯ СЛЕВА'),
                const SizedBox(height: 12),
                _GestureRow(task: demoTasks[1]),
                _GestureRow(task: demoTasks[2], hovered: true),
                _GestureRow(task: demoTasks[3]),
                _GestureRow(task: demoTasks[8]),
                const SizedBox(height: 10),
                const Text(
                  'Вторая строка показана под курсором: галочка проявляется только\n'
                  'при наведении, в покое список чистый. Пробел на выделенной строке\n'
                  'делает то же самое — для клавиатуры.',
                  style: TextStyle(color: _Ink.text3, fontSize: 12, height: 1.6),
                ),
                const SizedBox(height: 22),
                _caption('ОТМЕНА — ОБЯЗАТЕЛЬНА ДЛЯ ОБОИХ ДЕЙСТВИЙ'),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF241F19),
                    borderRadius: BorderRadius.circular(ClarifyRadius.pill),
                    border: Border.all(color: _Ink.borderStrong),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.check, size: 15, color: _Ink.done),
                      SizedBox(width: 10),
                      Text('Задача закрыта', style: TextStyle(color: _Ink.text, fontSize: 13.5, fontWeight: FontWeight.w600)),
                      SizedBox(width: 16),
                      Text('Отменить', style: TextStyle(color: _Ink.moved, fontSize: 13.5, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 28),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _caption('ТЕЛЕФОН — СВАЙП'),
              const SizedBox(height: 12),
              Container(
                width: 360,
                decoration: BoxDecoration(
                  color: _Ink.bg,
                  border: Border.all(color: _Ink.borderStrong, width: 8),
                  borderRadius: BorderRadius.circular(34),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: Column(
                    children: [
                      _SwipeRow(task: demoTasks[1], offset: 96, complete: true),
                      _SwipeRow(task: demoTasks[2], offset: 0),
                      _SwipeRow(task: demoTasks[3], offset: -150),
                      _SwipeRow(task: demoTasks[6], offset: 0),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const SizedBox(
                width: 360,
                child: Text(
                  'Вправо — закрыть задачу. Влево — не удаление сразу,\n'
                  'а две кнопки: перенести и удалить.',
                  style: TextStyle(color: _Ink.text3, fontSize: 12, height: 1.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _caption(String text) => Text(
        text,
        style: const TextStyle(
          color: _Ink.text3,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.3,
        ),
      );
}

class _GestureRow extends StatefulWidget {
  final PreviewTask task;
  final bool hovered;

  const _GestureRow({required this.task, this.hovered = false});

  @override
  State<_GestureRow> createState() => _GestureRowState();
}

class _GestureRowState extends State<_GestureRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final active = _hover || widget.hovered;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: ClarifyMotion.base,
        curve: ClarifyMotion.standard,
        constraints: const BoxConstraints(minHeight: 46),
        decoration: BoxDecoration(
          color: active ? const Color(0x0DF2EDE3) : Colors.transparent,
          border: const Border(bottom: BorderSide(color: _Ink.border)),
        ),
        child: Row(
          children: [
            // Зона выполнения: в покое пустая, при наведении проявляется
            // галочка. Ширина 30 — палец и курсор попадают, а в списке пусто.
            SizedBox(
              width: 30,
              child: AnimatedOpacity(
                duration: ClarifyMotion.base,
                opacity: active ? 1 : 0,
                child: Icon(
                  LucideIcons.check,
                  size: 17,
                  color: task.done ? _Ink.done : _Ink.text2,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.25,
                    fontWeight: FontWeight.w500,
                    color: task.done ? _Ink.text3 : _Ink.text,
                    decoration: task.done ? TextDecoration.lineThrough : null,
                    decorationColor: _Ink.text3,
                  ),
                ),
              ),
            ),
            if (task.durationMinutes > 0 && !task.done)
              Text('${task.durationMinutes} мин', style: const TextStyle(color: _Ink.text3, fontSize: 12)),
            if (task.time != null) ...[
              const SizedBox(width: 14),
              SizedBox(
                width: 42,
                child: Text(
                  task.time!,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: _Ink.text2,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }
}

/// Мобильная строка, показанная в момент свайпа: [offset] > 0 — тянут вправо
/// (закрыть), < 0 — влево (открылись кнопки).
class _SwipeRow extends StatelessWidget {
  final PreviewTask task;
  final double offset;
  final bool complete;

  const _SwipeRow({required this.task, required this.offset, this.complete = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      // Сдвинутая строка обязана обрезаться по краю экрана: без этого она
      // вылезает за рамку телефона — на настоящем устройстве так не бывает.
      child: ClipRect(
        child: Stack(
        children: [
          // Подложка действия — видна ровно настолько, насколько сдвинута строка.
          if (offset > 0)
            Positioned.fill(
              child: Container(
                color: _Ink.done.withValues(alpha: 0.22),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 22),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.check, size: 18, color: _Ink.done),
                    SizedBox(width: 10),
                    Text('Выполнено', style: TextStyle(color: _Ink.done, fontSize: 13, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          if (offset < 0)
            Positioned.fill(
              child: Container(
                alignment: Alignment.centerRight,
                color: const Color(0xFF241F19),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _action(LucideIcons.calendarClock, 'Перенести', _Ink.moved),
                    _action(LucideIcons.trash2, 'Удалить', _Ink.overdue),
                  ],
                ),
              ),
            ),
          Transform.translate(
            offset: Offset(offset, 0),
            child: Container(
              decoration: const BoxDecoration(
                color: _Ink.bg,
                border: Border(bottom: BorderSide(color: _Ink.border)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      task.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.25,
                        fontWeight: FontWeight.w500,
                        color: complete ? _Ink.text3 : _Ink.text,
                        decoration: complete ? TextDecoration.lineThrough : null,
                        decorationColor: _Ink.text3,
                      ),
                    ),
                  ),
                  if (task.time != null) ...[
                    const SizedBox(width: 12),
                    Text(
                      task.time!,
                      style: const TextStyle(
                        color: _Ink.text2,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _action(IconData icon, String label, Color color) {
    return Container(
      width: 75,
      height: double.infinity,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Вариант 4 — гибрид первого и второго, сразу в двух плотностях
// ---------------------------------------------------------------------------

/// Плотность строки. Это единственное, чем отличается ПК от телефона: анатомия
/// строки, шрифты и сигналы состояния одни и те же. Так десктоп и мобильный
/// перестают быть двумя разными реализациями, которые расходятся со временем
/// (сейчас это ровно так: task_cards.dart и mobile_task_row.dart живут своей
/// жизнью и уже разъехались).
enum RowDensity { desktop, mobile }

class HybridTaskRow extends StatelessWidget {
  final PreviewTask task;
  final RowDensity density;

  const HybridTaskRow({super.key, required this.task, required this.density});

  bool get _mobile => density == RowDensity.mobile;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bool urgent = task.overdue && !task.done;
    final bool rotting = task.rotDays >= 5 && !task.done;
    final bool hasSignals = urgent || rotting || task.rescheduled >= 3;
    final Color accent = urgent ? t.danger : _priorityColor(t, task.priority);

    // Высота: на ПК плотно (44), на телефоне не ниже 56 — палец меньше 48
    // логических пикселей не попадает, это не вкус, а требование к касанию.
    final double minHeight = _mobile ? 56 : 44;

    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: EdgeInsets.fromLTRB(_mobile ? 14 : 12, _mobile ? 10 : 7, _mobile ? 12 : 8, _mobile ? 10 : 7),
      decoration: BoxDecoration(
        // Заливка — только у того, что требует внимания. У обычной задачи фона
        // нет вовсе: именно одинаковый фон у всех строк и делал список
        // «стопкой одинаковых плиток».
        gradient: urgent
            ? LinearGradient(
                colors: [t.danger.withValues(alpha: 0.14), t.danger.withValues(alpha: 0)],
                stops: const [0, 0.5],
              )
            : null,
        border: Border(
          bottom: BorderSide(color: t.border.withValues(alpha: 0.5)),
          left: BorderSide(
            color: task.done || task.priority == 'none' && !urgent ? Colors.transparent : accent,
            width: urgent ? 3 : 2,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: _mobile ? 20 : 17,
            height: _mobile ? 20 : 17,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: task.done ? t.accent : Colors.transparent,
              border: Border.all(
                color: task.done
                    ? t.accent
                    : urgent
                        ? t.danger
                        : task.priority != 'none'
                            ? accent
                            : t.borderStrong,
                width: 1.5,
              ),
            ),
            child: task.done ? Icon(LucideIcons.check, size: _mobile ? 12 : 10, color: Colors.white) : null,
          ),
          SizedBox(width: _mobile ? 14 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  task.title,
                  maxLines: _mobile ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: urgent ? (_mobile ? 15.5 : 15.5) : (_mobile ? 15 : 14.5),
                    height: 1.25,
                    fontWeight: urgent ? FontWeight.w700 : FontWeight.w500,
                    color: task.done ? t.text3 : (rotting ? t.text2 : t.text),
                    decoration: task.done ? TextDecoration.lineThrough : null,
                    decorationColor: t.text3,
                  ),
                ),
                if (hasSignals)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 2,
                      children: [
                        if (urgent) _signal(t, LucideIcons.clockAlert, 'просрочено', t.danger),
                        if (task.rescheduled >= 3)
                          _signal(t, LucideIcons.arrowRight, 'перенос ×${task.rescheduled}', t.warning),
                        if (rotting) _signal(t, LucideIcons.hourglass, '${task.rotDays} дней', t.text3),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // Тег на телефоне не показываем: на 390px он отбирает ширину у
          // названия, ради которого строку и читают. На ПК места хватает.
          if (!_mobile && task.tag != null && !task.done) ...[
            const SizedBox(width: 10),
            Text('#${task.tag}', style: TextStyle(color: t.text3, fontSize: 12.5)),
          ],
          if (task.checklistTotal > 0) ...[
            const SizedBox(width: 10),
            Text(
              '${task.checklistDone}/${task.checklistTotal}',
              style: TextStyle(
                color: t.text3,
                fontSize: 12,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
          if (task.time != null) ...[
            const SizedBox(width: 10),
            Text(
              task.time!,
              style: TextStyle(
                color: urgent ? t.danger : t.text2,
                fontSize: _mobile ? 13 : 12.5,
                fontWeight: urgent ? FontWeight.w700 : FontWeight.w500,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _signal(ClarifyTokens t, IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _VariantHybrid extends StatelessWidget {
  const _VariantHybrid();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 40, right: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label(t, 'ПК — 44px на строку'),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView(
                    children: [
                      for (final task in demoTasks)
                        HybridTaskRow(task: task, density: RowDensity.desktop),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label(t, 'Телефон — 390px, 56px на строку'),
              const SizedBox(height: 10),
              // Реальная ширина экрана телефона, а не «примерно узкое место»:
              // иначе не увидеть, что именно перестаёт помещаться.
              Container(
                width: 390,
                height: 560,
                decoration: BoxDecoration(
                  color: t.bg,
                  border: Border.all(color: t.borderStrong, width: 8),
                  borderRadius: BorderRadius.circular(34),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: ListView(
                    padding: const EdgeInsets.only(top: 8),
                    children: [
                      for (final task in demoTasks)
                        HybridTaskRow(task: task, density: RowDensity.mobile),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _label(ClarifyTokens t, String text) {
    return Text(
      text,
      style: TextStyle(color: t.text3, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1),
    );
  }
}

// ---------------------------------------------------------------------------
// Вариант 3 — «День на оси»
// ---------------------------------------------------------------------------

class _VariantTimeline extends StatelessWidget {
  const _VariantTimeline();

  static const _startHour = 8;
  static const _endHour = 21;
  static const _hourHeight = 46.0;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final timed = demoTasks.where((task) => task.time != null && !task.done).toList();
    final untimed = demoTasks.where((task) => task.time == null && !task.done).toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(left: 40, bottom: 40),
            child: SizedBox(
              height: (_endHour - _startHour + 1) * _hourHeight,
              child: Stack(
                children: [
                  for (var hour = _startHour; hour <= _endHour; hour++)
                    Positioned(
                      top: (hour - _startHour) * _hourHeight,
                      left: 0,
                      right: 0,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 42,
                            child: Text(
                              '${hour.toString().padLeft(2, '0')}:00',
                              style: TextStyle(
                                color: t.text3.withValues(alpha: 0.7),
                                fontSize: 11,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                          Expanded(child: Container(height: 1, color: t.border.withValues(alpha: 0.45))),
                        ],
                      ),
                    ),
                  for (final task in timed) _block(t, task),
                ],
              ),
            ),
          ),
        ),
        SizedBox(
          width: 250,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 40, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'БЕЗ ВРЕМЕНИ',
                  style: TextStyle(
                    color: t.text3,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                for (final task in untimed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: t.surface,
                        borderRadius: BorderRadius.circular(ClarifyRadius.sm),
                        border: Border.all(color: t.border),
                      ),
                      child: Text(
                        task.title,
                        maxLines: 2,
                        style: TextStyle(color: t.text2, fontSize: 13, height: 1.35),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _block(ClarifyTokens t, PreviewTask task) {
    final parts = task.time!.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final top = (hour - _startHour) * _hourHeight + (minute / 60) * _hourHeight;
    final height = (task.durationMinutes / 60) * _hourHeight;
    final color = task.overdue ? t.danger : _priorityColor(t, task.priority);

    return Positioned(
      top: top,
      left: 52,
      right: 8,
      height: height < 26 ? 26 : height,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: (task.priority == 'none' ? t.accent : color).withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(6),
          border: Border(
            left: BorderSide(color: task.priority == 'none' ? t.accent : color, width: 3),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                task.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: t.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${task.durationMinutes} мин',
              style: TextStyle(color: t.text3, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
