import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/config.dart';
import '../core/localization.dart';
import '../core/theme/design_tokens.dart';

/// Анимированный кружок выполнения задачи — замена стокового
/// `Checkbox(shape: CircleBorder())`, у которого не было вообще никакой
/// анимации кроме дефолтного ripple. Заливка и галочка "дорисовываются"
/// (fade+рост), не мгновенный скачок. Сдержанно — без bounce/overshoot
/// (см. эталон движения v3, `ClarifyMotion.standard`, не `.spring`).
class ClarifyCheckCircle extends StatefulWidget {
  final bool value;
  final VoidCallback? onTap;
  final double size;
  final Color borderColor;
  final Color checkedColor;
  final Color checkIconColor;
  final double borderWidth;
  // По умолчанию — обычный темп (чек-лист/подзадачи, где отметка должна
  // ощущаться быстрой). Основная задача в списке передаёт
  // ClarifyMotion.completion явно — единый темп со strike-through/фоном
  // строки для одного и того же жеста завершения.
  final Duration duration;

  const ClarifyCheckCircle({
    super.key,
    required this.value,
    required this.onTap,
    required this.borderColor,
    required this.checkedColor,
    this.size = 22,
    this.checkIconColor = Colors.white,
    this.borderWidth = 2.0,
    this.duration = ClarifyMotion.base,
  });

  @override
  State<ClarifyCheckCircle> createState() => _ClarifyCheckCircleState();
}

class _ClarifyCheckCircleState extends State<ClarifyCheckCircle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: widget.value ? 1 : 0,
    );
    _progress = CurvedAnimation(
      parent: _controller,
      curve: ClarifyMotion.standard,
    );
  }

  @override
  void didUpdateWidget(covariant ClarifyCheckCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      final duration = MediaQuery.of(context).disableAnimations
          ? Duration.zero
          : widget.duration;
      _controller.animateTo(widget.value ? 1 : 0, duration: duration);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _progress,
        builder: (context, _) {
          final t = _progress.value.clamp(0.0, 1.0);
          return Container(
            width: widget.size,
            height: widget.size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color.lerp(Colors.transparent, widget.checkedColor, t),
              border: Border.all(
                color: Color.lerp(widget.borderColor, widget.checkedColor, t)!,
                width: widget.borderWidth,
              ),
            ),
            child: t > 0.02
                ? Opacity(
                    opacity: t,
                    child: Icon(
                      LucideIcons.check,
                      size: widget.size * 0.62,
                      color: widget.checkIconColor,
                    ),
                  )
                : null,
          );
        },
      ),
    );
  }
}

/// Анимированное зачёркивание текста — линия "дорисовывается" слева направо
/// при выполнении, при отмене — растворяется (не мгновенно исчезает). Цвет
/// самого текста не анимируется (это решает вызывающий код), только линия.
class ClarifyStrikeText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final bool isDone;
  final int? maxLines;
  final TextOverflow overflow;
  final Color? strikeColor;

  const ClarifyStrikeText({
    super.key,
    required this.text,
    required this.style,
    required this.isDone,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.strikeColor,
  });

  @override
  State<ClarifyStrikeText> createState() => _ClarifyStrikeTextState();
}

class _ClarifyStrikeTextState extends State<ClarifyStrikeText>
    with TickerProviderStateMixin {
  // Два раздельных прогресса, а не один реверсируемый: "растворяется" на
  // отмене должно быть затуханием прозрачности уже нарисованной линии, а не
  // тем же сжатием ширины назад, что и рисование при выполнении — иначе
  // (см. баг) на середине анимации отмены линия визуально "проскакивает"
  // мимо короткого текста и обрывается раньше, чем реально дотухла.
  late final AnimationController
  _draw; // 0 → 1: линия дорисовывается слева направо
  late final AnimationController
  _fade; // 1 → 0: дорисованная линия растворяется

  @override
  void initState() {
    super.initState();
    // Дорисовка — на ClarifyMotion.completion (900мс, единый темп со всеми
    // остальными фронтами того же жеста завершения — заливка чекбокса, фон
    // строки, полоса приоритета), а не на общий ClarifyMotion.base (180мс,
    // слишком быстрый для линии через всё слово). Растворение при отмене
    // остаётся на base — там жалоб не было.
    _draw = AnimationController(
      vsync: this,
      duration: ClarifyMotion.completion,
      value: widget.isDone ? 1 : 0,
    );
    _fade = AnimationController(
      vsync: this,
      duration: ClarifyMotion.base,
      value: 1,
    );
  }

  @override
  void didUpdateWidget(covariant ClarifyStrikeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDone != widget.isDone) {
      final reduceMotion = MediaQuery.of(context).disableAnimations;
      final duration = reduceMotion ? Duration.zero : ClarifyMotion.base;
      if (widget.isDone) {
        _fade.value = 1;
        _draw.value = 0;
        _draw.animateTo(
          1,
          duration: reduceMotion ? Duration.zero : ClarifyMotion.completion,
        );
      } else {
        _fade.value = 1;
        _fade.animateTo(0, duration: duration).whenCompleteOrCancel(() {
          if (!mounted) return;
          _draw.value = 0;
          _fade.value = 1;
        });
      }
    }
  }

  @override
  void dispose() {
    _draw.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.strikeColor ?? widget.style.color ?? Colors.black;
    return LayoutBuilder(
      builder: (context, constraints) {
        // IntrinsicWidth не помогает здесь: вызывающий код кладёт этот виджет
        // в Expanded, который даёт ЖЁСТКИЕ (tight) constraints — под ними
        // IntrinsicWidth ничего не сжимает, он влияет только на свободные
        // (loose) constraints. Поэтому ширина текста меряется явно через
        // TextPainter (с тем же maxLines/overflow, что и у самого Text) —
        // раньше линия растягивалась на всю ширину Expanded-родителя вместо
        // ширины реального текста.
        final painter =
            TextPainter(
              text: TextSpan(text: widget.text, style: widget.style),
              maxLines: widget.maxLines,
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
              ellipsis: widget.overflow == TextOverflow.ellipsis ? '…' : null,
              // TextWidthBasis.parent (дефолт) отдаёт в .width практически весь
              // maxWidth констрейнта, а не фактическую ширину глифов — если строка
              // короче доступного места (обычный случай в Expanded), черта
              // рисовалась на всю ширину слота, а не по факту символов текста.
              textWidthBasis: TextWidthBasis.longestLine,
            )..layout(
              maxWidth: constraints.hasBoundedWidth
                  ? constraints.maxWidth
                  : double.infinity,
            );
        final textWidth = painter.width;

        return Stack(
          alignment: Alignment.centerLeft,
          children: [
            Text(
              widget.text,
              style: widget.style,
              maxLines: widget.maxLines,
              overflow: widget.overflow,
            ),
            AnimatedBuilder(
              animation: Listenable.merge([_draw, _fade]),
              builder: (context, _) {
                final width = CurvedAnimation(
                  parent: _draw,
                  curve: ClarifyMotion.standard,
                ).value.clamp(0.0, 1.0);
                final opacity = CurvedAnimation(
                  parent: _fade,
                  curve: ClarifyMotion.standard,
                ).value.clamp(0.0, 1.0);
                if (width <= 0.001 || opacity <= 0.001)
                  return const SizedBox.shrink();
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Opacity(
                    opacity: opacity,
                    child: Container(
                      width: textWidth * width,
                      height: 1.4,
                      color: color,
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

/// Значок наличия чек-листа на карточке задачи — иконка списка + "done/total"
/// в закрашенной пилюле, а не голые "[done/total]" в цвете обычного текста
/// (легко спутать с произвольной пометкой, не читается как индикатор
/// прогресса на беглый взгляд). Фон зелёный, когда все подзадачи выполнены,
/// иначе нейтральный акцентный.
class ClarifySubtaskBadge extends StatelessWidget {
  final int done;
  final int total;
  final ClarifyTokens tokens;
  final double scale;
  final IconData icon;

  const ClarifySubtaskBadge({
    super.key,
    required this.done,
    required this.total,
    required this.tokens,
    this.scale = 1.0,
    this.icon = LucideIcons.listChecks,
  });

  @override
  Widget build(BuildContext context) {
    final bool allDone = total > 0 && done == total;
    final Color fg = allDone ? tokens.success : tokens.text2;
    final Color bg = allDone ? tokens.successSoft : tokens.accentSoft;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6 * scale, vertical: 2 * scale),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(ClarifyRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12 * scale, color: fg),
          SizedBox(width: 3 * scale),
          Text(
            '$done/$total',
            style: TextStyle(
              fontSize: 11.5 * scale,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Плавное появление для новых сигналов-предупреждений (бейджи гниения/
/// переноса, банер перегрузки дня) — раньше появлялись/исчезали мгновенно,
/// выбиваясь из общей моушн-системы (даже чекбокс/зачёркивание анимируются
/// через ClarifyMotion). Fade+едва заметный scale-in по ClarifyMotion.standard
/// — это появление состояния, не жест (см. gesture/state правило
/// REDESIGN_V4_PLAN.md §6.7), поэтому .standard, не .spring.
class ClarifyBadgeEntrance extends StatelessWidget {
  final Widget child;
  const ClarifyBadgeEntrance({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // TweenAnimationBuilder вместо ручного AnimationController+State: он сам
    // по себе анимирует begin→end при каждом ПЕРВОМ построении (т.е. при
    // монтировании виджета) без отдельного жизненного цикла, который раньше
    // держал этот же эффект на State.didChangeDependencies — тот вариант
    // либо не всегда успевал сработать до первой отрисовки, либо путался с
    // переиспользованием элемента в Wrap, и на практике вход не был заметен.
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: reduceMotion ? Duration.zero : ClarifyMotion.base,
      curve: ClarifyMotion.standard,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.scale(scale: 0.85 + 0.15 * t, child: child),
      ),
      child: child,
    );
  }
}

/// Показывает/прячет бейдж (buildRotBadge/buildRescheduleBadge — null, если
/// неприменимо) с анимацией в ОБЕ стороны, в отличие от [ClarifyBadgeEntrance]
/// (только вход). Первая попытка была на AnimatedSwitcher — на практике
/// исчезновение "дёргалось по кадрам": его дефолтный layoutBuilder кладёт
/// уходящий виджет в Stack, размер которого сразу схлопывается до размера
/// ВХОДЯЩЕГО (нулевого) ребёнка — уходящий виджet зажимался в этот нулевой
/// Stack раньше, чем успевал реально дотухнуть по прозрачности. AnimatedSize
/// (тот же, уже проверенный приём, что и у бейджа подзадач ниже) меняет
/// размер контейнера плавно кадр за кадром, а не одним скачком через Stack —
/// вместе с AnimatedOpacity для самого затухания получается настоящий плавный
/// уход, не только вход.
Widget clarifyAnimatedBadgeSlot(Widget? badge) =>
    _ClarifyAnimatedBadgeSlot(badge: badge);

/// StatefulWidget, а не просто функция — раньше, в момент, когда [badge]
/// становился `null` (например при отметке задачи выполненной), REBUILD
/// подменял ребёнка AnimatedOpacity на SizedBox.shrink() В ТОМ ЖЕ кадре, что
/// и запускал анимацию прозрачности к 0. AnimatedOpacity анимирует только
/// свойство opacity ОДНОГО и того же виджета-ребёнка — если сам ребёнок уже
/// подменён на пустой SizedBox, буквально нечему становиться прозрачным, и
/// бейдж исчезал мгновенно (живой фидбек: "появляются красиво анимировано,
/// пропадают резко"). Держим последний НЕ-null бейдж в состоянии и рендерим
/// именно его во время затухания — сам виджет остаётся смонтированным, пока
/// не долетит до нулевой прозрачности, и только тогда (после AnimatedSize)
/// схлопывается по размеру.
class _ClarifyAnimatedBadgeSlot extends StatefulWidget {
  final Widget? badge;
  const _ClarifyAnimatedBadgeSlot({this.badge});

  @override
  State<_ClarifyAnimatedBadgeSlot> createState() =>
      _ClarifyAnimatedBadgeSlotState();
}

class _ClarifyAnimatedBadgeSlotState extends State<_ClarifyAnimatedBadgeSlot> {
  Widget? _lastBadge;

  @override
  void initState() {
    super.initState();
    _lastBadge = widget.badge;
  }

  @override
  void didUpdateWidget(covariant _ClarifyAnimatedBadgeSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Обновляем "последний показанный бейдж" только когда он реально есть —
    // когда badge становится null, специально НЕ затираем _lastBadge, чтобы
    // было что плавно растворять.
    if (widget.badge != null) {
      _lastBadge = widget.badge;
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.badge != null;
    return AnimatedSize(
      duration: ClarifyMotion.completion,
      curve: ClarifyMotion.standard,
      alignment: Alignment.centerLeft,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: ClarifyMotion.completion,
        curve: ClarifyMotion.standard,
        child: _lastBadge ?? const SizedBox.shrink(),
      ),
    );
  }
}

/// Обобщённый бейдж-пилюля (иконка + короткая подпись) — тот же визуальный
/// язык, что и у [ClarifySubtaskBadge], но без привязки к формату "N/M":
/// используется для сигналов "задача давно не двигалась" и "перенесена N
/// раз" на карточках списка/доски (см. task_cards.dart).
class ClarifyInfoBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color fg;
  final Color bg;
  final double scale;

  const ClarifyInfoBadge({
    super.key,
    required this.icon,
    required this.label,
    required this.fg,
    required this.bg,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6 * scale, vertical: 2 * scale),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(ClarifyRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12 * scale, color: fg),
          SizedBox(width: 3 * scale),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5 * scale,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Гниющая" задача (task rot) — невыполненная, без активного будущего
/// дедлайна (нет даты или дедлайн уже прошёл) и созданная давно, никак
/// раньше не выделялась среди свежих задач. Общая функция для десктопных
/// карточек (task_cards.dart) и мобильной строки (mobile_task_row.dart) —
/// раньше жила только в TaskCardBuilders, из-за чего бейдж не появлялся на
/// мобильном (MobileTaskRow — отдельный виджет, не переиспользует
/// TaskCardBuilders). Приоритет 'red' даёт более тревожный (danger, не
/// warning) цвет: важная задача, которая простаивает, сильнее нуждается во
/// внимании, чем рядовая (см. идею "срочное вытесняет важное" — один и тот
/// же механизм с разной окраской, а не отдельная система).
Widget? buildRotBadge({
  required Map<String, dynamic> task,
  required bool isDone,
  required bool overdue,
  required ClarifyTokens tokens,
  required String currentLang,
  double scale = 1.0,
}) {
  if (isDone) return null;
  if (!(task['due_date'] == null || overdue)) return null;
  final createdAt = DateTime.tryParse(task['created_at']?.toString() ?? '');
  if (createdAt == null) return null;
  final ageDays = DateTime.now().difference(createdAt).inDays;
  if (ageDays < AppConfig.taskRotDays) return null;
  final bool isImportant = task['priority'] == 'red';
  // Не оборачиваем в ClarifyBadgeEntrance здесь — вызывающий код заворачивает
  // в AnimatedSwitcher (см. task_cards.dart/mobile_task_row.dart), который
  // сам даёт и вход, и выход одной и той же анимацией; двойная обёртка дала
  // бы вход дважды и никакого выхода (ClarifyBadgeEntrance не умеет уходить).
  return Tooltip(
    message:
        '${"Задача не двигается уже".tr(currentLang)} $ageDays ${"дн.".tr(currentLang)}',
    child: ClarifyInfoBadge(
      icon: LucideIcons.archive,
      label: '$ageDays ${"дн.".tr(currentLang)}',
      fg: isImportant ? tokens.danger : tokens.warning,
      bg: isImportant ? tokens.dangerSoft : tokens.warningSoft,
      scale: scale,
    ),
  );
}

/// Перенос даты вперёд N+ раз (см. AppConfig.rescheduleWarningCount) — общая
/// функция, см. doc [buildRotBadge] про причину вынесения из TaskCardBuilders.
Widget? buildRescheduleBadge({
  required Map<String, dynamic> task,
  required bool isDone,
  required ClarifyTokens tokens,
  required String currentLang,
  double scale = 1.0,
}) {
  if (isDone) return null;
  final count = task['reschedule_count'] as int?;
  if (count == null || count < AppConfig.rescheduleWarningCount) return null;
  return Tooltip(
    message: '${"Перенесена".tr(currentLang)} $count ${"раз".tr(currentLang)}',
    child: ClarifyInfoBadge(
      icon: LucideIcons.history,
      label: '×$count',
      fg: tokens.warning,
      bg: tokens.warningSoft,
      scale: scale,
    ),
  );
}
