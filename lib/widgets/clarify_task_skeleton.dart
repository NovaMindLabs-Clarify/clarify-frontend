import 'package:flutter/material.dart';

import '../core/app_settings.dart';
import '../core/theme/design_tokens.dart';

/// Силуэты строк задач на время первой загрузки (D3).
///
/// До этого при холодном старте — пустой кэш, данные ещё летят — список
/// показывал ПУСТОЕ СОСТОЯНИЕ: «Задач пока нет» с иллюстрацией. То есть новому
/// человеку в первую же секунду сообщалось, что у него ничего нет, а через
/// мгновение экран менялся на список. Силуэт честнее: он говорит «сейчас
/// будет», а не делает утверждение, которое тут же опровергается.
///
/// Мерцание намеренно очень спокойное и подчиняется «меньше анимаций»: это
/// фон ожидания, а не элемент, который надо разглядывать.
class ClarifyTaskSkeleton extends StatefulWidget {
  /// Сколько силуэтов рисовать. По умолчанию — примерно экран.
  final int rows;
  final double scale;

  const ClarifyTaskSkeleton({super.key, this.rows = 7, this.scale = 1.0});

  @override
  State<ClarifyTaskSkeleton> createState() => _ClarifyTaskSkeletonState();
}

class _ClarifyTaskSkeletonState extends State<ClarifyTaskSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    // Своё число, а не токен движения: токены — про переходы интерфейса, а
    // это фоновое дыхание ожидания. Оно обязано быть заметно медленнее любого
    // перехода, иначе силуэты начинают мельтешить и притягивать взгляд к
    // тому, на что смотреть не нужно.
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (!AppSettings.reducedMotionOverride.value) _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final rs = widget.scale;

    // Ширины намеренно разные и заданы явно, а не случайны: случайная ширина
    // менялась бы при каждой перерисовке и силуэты дёргались бы.
    const widths = [0.62, 0.45, 0.74, 0.38, 0.55, 0.68, 0.42];

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final opacity = 0.35 + 0.25 * _controller.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < widget.rows; i++)
              Container(
                height: 44 * rs,
                padding: EdgeInsets.symmetric(vertical: 12 * rs),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: t.border)),
                ),
                child: Row(
                  children: [
                    SizedBox(width: 32 * rs),
                    Expanded(
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: widths[i % widths.length],
                        child: Container(
                          height: 11 * rs,
                          decoration: BoxDecoration(
                            color: t.text3.withValues(alpha: opacity * 0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16 * rs),
                    Container(
                      width: 90 * rs,
                      height: 11 * rs,
                      decoration: BoxDecoration(
                        color: t.text3.withValues(alpha: opacity * 0.35),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    SizedBox(width: 8 * rs),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
