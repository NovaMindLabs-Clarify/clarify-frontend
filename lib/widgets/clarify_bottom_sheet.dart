import 'package:flutter/material.dart';
import 'clarify_glass.dart';
import '../core/theme/design_tokens.dart';

/// Мобильный аналог [showClarifySurface] — шторка снизу вместо центрированного
/// диалога. Десктопные диалоги, механически перенесённые на мобильный экран
/// как есть, — ровно то, из-за чего мобильная версия «выглядит сжатым
/// десктопом» (REDESIGN_V2_PLAN.md §3.7).
Future<T?> showClarifyBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  final t = context.tokens;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    // ЭКСПЕРИМЕНТАЛЬНО (см. showClarifyBottomSheet doc-комментарий выше):
    // ручной Padding под viewInsets.bottom убран — похоже, само значение,
    // которое Flutter Web получает от мобильного Safari на первом фокусе
    // поля, завышено (не проблема анимации, AnimatedPadding не помог).
    // Пробуем отдать позиционирование браузеру (нативный scroll-into-view
    // фокусed-поля) вместо ручной компенсации, которая, похоже, сама и
    // была источником "улёта" листа наверх.
    builder: (context) => ClarifyGlass(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        showHighlight: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: t.border, borderRadius: BorderRadius.circular(999))),
              const SizedBox(height: 8),
              Flexible(child: Builder(builder: builder)),
            ],
          ),
        ),
      ),
  );
}
