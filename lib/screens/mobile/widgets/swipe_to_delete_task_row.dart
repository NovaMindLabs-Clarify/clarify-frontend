import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/app_settings.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/localization.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../widgets/clarify_toast.dart';
import 'mobile_task_row.dart';

/// Обёртка над [MobileTaskRow] — свайп вместо тапа по крестику (REDESIGN_V3_PLAN.md
/// §3.11/5.11): свайп прячет строку сразу, но реальное удаление на бэкенд
/// уходит только через несколько секунд — окно, за которое можно нажать
/// «Отменить» в тосте и вернуть задачу. Если экран закрылся раньше, чем истекло
/// окно, удаление всё равно происходит — свайп уже был осознанным подтверждением.
class SwipeToDeleteTaskRow extends StatefulWidget {
  final Map<String, dynamic> task;
  final Color priorityColor;
  final Map<String, int> subtaskStats;
  final bool overdue;
  final String currentLang;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final VoidCallback onConfirmedDelete;
  final void Function(Map<String, dynamic> updates) onQuickUpdateTask;
  final bool showDate;

  const SwipeToDeleteTaskRow({
    super.key,
    required this.task,
    required this.priorityColor,
    required this.subtaskStats,
    required this.overdue,
    required this.currentLang,
    required this.onToggle,
    required this.onTap,
    required this.onConfirmedDelete,
    required this.onQuickUpdateTask,
    this.showDate = false,
  });

  @override
  State<SwipeToDeleteTaskRow> createState() => _SwipeToDeleteTaskRowState();
}

class _SwipeToDeleteTaskRowState extends State<SwipeToDeleteTaskRow> {
  bool _pendingDelete = false;
  Timer? _timer;

  static const _undoWindow = Duration(seconds: 4);

  void _startDelete() {
    setState(() => _pendingDelete = true);
    ClarifyToast.show(
      context,
      'Задача удалена'.tr(widget.currentLang),
      variant: ClarifyToastVariant.danger,
      duration: _undoWindow,
      actionLabel: 'Отменить'.tr(widget.currentLang),
      onAction: _cancel,
    );
    _timer = Timer(_undoWindow, () {
      if (mounted) widget.onConfirmedDelete();
    });
  }

  void _cancel() {
    _timer?.cancel();
    if (mounted) setState(() => _pendingDelete = false);
  }

  @override
  void dispose() {
    // Экран закрылся раньше окна отмены — свайп уже был подтверждением,
    // поэтому удаление доводится до конца, а не молча теряется.
    if (_pendingDelete && (_timer?.isActive ?? false)) {
      widget.onConfirmedDelete();
    }
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    // Раньше при удалении/отмене этот виджет мгновенно схлопывался в
    // SizedBox.shrink() ровно на этом месте — сама задача пропадала/
    // появлялась одним кадром, а соседние строки в ReorderableListView
    // дёргались на её место так же резко. AnimatedSize вместо голого if —
    // высота едет плавно в обе стороны, и остальные задачи сами уезжают
    // вверх/вниз вместе с ней, без отдельной анимации на каждую соседнюю
    // строку.
    return AnimatedSize(
      duration: reduceMotion ? Duration.zero : ClarifyMotion.slow,
      curve: ClarifyMotion.standard,
      alignment: Alignment.topCenter,
      child: _pendingDelete
          ? const SizedBox.shrink()
          : Dismissible(
              key: ValueKey('swipe_delete_${widget.task['id']}'),
              // Свайп в обе стороны (2026-09-04): влево — удалить, вправо —
              // закрыть задачу. Раньше был только влево, и самое частое
              // действие оставалось без жеста вовсе.
              direction: DismissDirection.horizontal,
              confirmDismiss: (direction) async {
                if (direction == DismissDirection.startToEnd) {
                  // Отметка выполненной — НЕ удаление: строку не убираем,
                  // задача просто меняет состояние и сама уезжает в конец
                  // списка. Поэтому false: Dismissible возвращает её на место,
                  // а дальше работает обычная анимация переезда.
                  widget.onToggle();
                  return false;
                }
                return true;
              },
              onDismissed: (_) => _startDelete(),
              background: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: t.successSoft,
                  borderRadius: BorderRadius.circular(ClarifyRadius.md),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.task['is_completed'] == true
                          ? LucideIcons.rotateCcw
                          : LucideIcons.check,
                      color: t.success,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      (widget.task['is_completed'] == true ? 'Вернуть' : 'Выполнено')
                          .tr(widget.currentLang),
                      style: TextStyle(color: t.success, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              secondaryBackground: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                alignment: Alignment.centerRight,
                decoration: BoxDecoration(color: t.danger, borderRadius: BorderRadius.circular(ClarifyRadius.md)),
                child: Icon(LucideIcons.trash2, color: Colors.white),
              ),
              child: MobileTaskRow(
                              compact: AppSettings.compactDensity.value,
                task: widget.task,
                priorityColor: widget.priorityColor,
                subtaskStats: widget.subtaskStats,
                overdue: widget.overdue,
                currentLang: widget.currentLang,
                onToggle: widget.onToggle,
                onDelete: _startDelete,
                onTap: widget.onTap,
                onQuickUpdateTask: widget.onQuickUpdateTask,
                showDate: widget.showDate,
              ),
            ),
    );
  }
}
