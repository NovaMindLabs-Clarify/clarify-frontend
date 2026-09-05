import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/localization.dart';
import '../core/theme/design_tokens.dart';
import 'clarify_button.dart';
import 'clarify_illustrations.dart';
import 'clarify_toast.dart';

/// Корзина (C6 из docs/AUDIT_2026-09-04.md).
///
/// Задача удалялась сразу и навсегда, а отменить это можно было только в
/// пределах анимации свайпа на мобильном — при том что крестик удаления висит в
/// каждой строке списка. Теперь удаление откладывается на 30 дней.
///
/// Содержимое грузится отдельным запросом и только когда раздел открыт: держать
/// удалённое в общем кэше задач означало бы отфильтровывать его в каждом
/// списке, а так фильтр нужен ровно один — в fetchTasks.
class TrashScreen extends StatefulWidget {
  final String currentLang;
  final double scale;
  final int retentionDays;
  final Future<List<Map<String, dynamic>>> Function() loadTrash;
  final Future<void> Function(int taskId) onRestore;
  final Future<void> Function(int taskId) onDeleteForever;

  const TrashScreen({
    super.key,
    required this.currentLang,
    required this.scale,
    required this.loadTrash,
    required this.onRestore,
    required this.onDeleteForever,
    this.retentionDays = 30,
  });

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  List<Map<String, dynamic>>? _items;
  String? _error;
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _error = null);
    try {
      final items = await widget.loadTrash();
      if (!mounted) return;
      setState(() {
        _items = items;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      // Пользователю — человеческая фраза, а не e.toString(). Живьём это
      // выглядело как «Не удалось загрузить корзину: TimeoutException after
      // 0:00:15.000000: Future not completed» — текст, из которого нельзя
      // понять ни что случилось, ни что делать (05.09.2026).
      setState(() => _error = _humanError(e));
    }
  }

  /// Отличаем «нет связи» от «что-то сломалось»: в первом случае помогает
  /// повторить, во втором — нет, и обещать обратное нечестно.
  String _humanError(Object e) {
    final text = e.toString().toLowerCase();
    final offline =
        text.contains('timeout') ||
        text.contains('socket') ||
        text.contains('failed host lookup') ||
        text.contains('connection');
    return offline
        ? 'Нет связи с сервером. Проверьте интернет и повторите.'
        : 'Не удалось загрузить корзину.';
  }

  Future<void> _act(int taskId, Future<void> Function(int) action, String doneMessage) async {
    setState(() => _busy.add(taskId));
    try {
      await action(taskId);
      if (!mounted) return;
      setState(() => _items?.removeWhere((t) => t['id'] == taskId));
      ClarifyToast.show(context, doneMessage.tr(widget.currentLang), variant: ClarifyToastVariant.success);
    } catch (e) {
      if (!mounted) return;
      ClarifyToast.show(
        context,
        '${'Не удалось: '.tr(widget.currentLang)}$e',
        variant: ClarifyToastVariant.danger,
      );
    } finally {
      if (mounted) setState(() => _busy.remove(taskId));
    }
  }

  /// «Удалим через N дней» — обещание из этого же экрана должно быть видно
  /// рядом с каждой задачей, иначе корзина выглядит как вечное хранилище.
  String _remainingLabel(dynamic rawDeletedAt) {
    final deletedAt = DateTime.tryParse(rawDeletedAt?.toString() ?? '');
    if (deletedAt == null) return '';
    final left = widget.retentionDays - DateTime.now().difference(deletedAt).inDays;
    if (left <= 0) return 'удалится со дня на день'.tr(widget.currentLang);
    if (left == 1) return 'удалится завтра'.tr(widget.currentLang);
    return '${'удалится через'.tr(widget.currentLang)} $left ${_dayWord(left)}';
  }

  String _dayWord(int n) {
    if (widget.currentLang != 'ru') return 'days';
    final mod100 = n % 100;
    if (mod100 >= 11 && mod100 <= 14) return 'дней';
    switch (n % 10) {
      case 1:
        return 'день';
      case 2:
      case 3:
      case 4:
        return 'дня';
      default:
        return 'дней';
    }
  }

  /// Масштаб, пригодный для ТЕКУЩЕЙ ширины, а не для десктопного окна.
  ///
  /// Экран один и тот же для ПК и телефона, а `scale` приходил из
  /// DesktopPlannerScreen, где он считается как ширина/1920 и на телефоне
  /// упирается в нижнюю границу 0.4. Весь текст умножался на 0.4 — заголовок
  /// задачи в 15px превращался в 6px, а кнопки на такой множитель не
  /// сжимаются и выглядели рядом огромными (живой фидбек 06.09.2026).
  ///
  /// Мобильные экраны в проекте рисуются в натуральную величину и множителя не
  /// знают — здесь так же.
  double _scaleFor(double width) => width < 700 ? 1.0 : widget.scale;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final s = _scaleFor(MediaQuery.sizeOf(context).width);

    if (_error != null) {
      // С кнопкой, а не одной строкой текста: раньше из этого состояния не
      // было выхода вообще — оставалось переключаться на другой раздел и
      // возвращаться, чтобы экран построился заново.
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClarifyIllustration(type: ClarifyIllustrationType.trashEmpty, size: 84),
            const SizedBox(height: 18),
            Text(
              _error!.tr(widget.currentLang),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14 * s, color: t.text2),
            ),
            const SizedBox(height: 14),
            ClarifyButton(
              label: 'Повторить'.tr(widget.currentLang),
              icon: LucideIcons.refreshCw,
              scale: s,
              onPressed: () {
                setState(() {
                  _error = null;
                  _items = null;
                });
                _load();
              },
            ),
          ],
        ),
      );
    }

    if (_items == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items!.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClarifyIllustration(type: ClarifyIllustrationType.trashEmpty, size: 84),
            const SizedBox(height: 18),
            Text(
              'Корзина пуста'.tr(widget.currentLang),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: t.text2),
            ),
            const SizedBox(height: 7),
            Text(
              '${'Удалённые задачи хранятся'.tr(widget.currentLang)} ${widget.retentionDays} ${_dayWord(widget.retentionDays)}',
              style: TextStyle(fontSize: 13, color: t.text3),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 24 * s, vertical: 4 * s),
      itemCount: _items!.length,
      itemBuilder: (context, index) {
        final task = _items![index];
        final int id = task['id'] as int;
        final bool busy = _busy.contains(id);

        return Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: t.border)),
          ),
          padding: EdgeInsets.symmetric(vertical: 10 * s),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // На телефоне две подписанные кнопки рядом с заголовком не
              // помещаются: заголовок сжимался в узкую полоску, а кнопки
              // занимали почти всю строку. Узко — значит действия уходят под
              // задачу, где им хватает места.
              final narrow = constraints.maxWidth < 480;

              final title = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (task['title'] ?? '').toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15 * s, color: t.text2),
                  ),
                  SizedBox(height: 2 * s),
                  Text(
                    _remainingLabel(task['deleted_at']),
                    style: TextStyle(fontSize: 12 * s, color: t.text3),
                  ),
                ],
              );

              if (busy) {
                return Row(
                  children: [
                    Expanded(child: title),
                    SizedBox(
                      width: 16 * s,
                      height: 16 * s,
                      child: CircularProgressIndicator(strokeWidth: 2, color: t.text3),
                    ),
                  ],
                );
              }

              final restore = ClarifyButton(
                label: 'Восстановить'.tr(widget.currentLang),
                icon: LucideIcons.undo2,
                variant: ClarifyButtonVariant.outline,
                scale: 0.85 * s,
                onPressed: () => _act(id, widget.onRestore, 'Задача восстановлена'),
              );
              final purge = ClarifyButton(
                label: 'Удалить навсегда'.tr(widget.currentLang),
                icon: LucideIcons.trash2,
                variant: ClarifyButtonVariant.danger,
                scale: 0.85 * s,
                onPressed: () => _act(id, widget.onDeleteForever, 'Задача удалена навсегда'),
              );

              if (!narrow) {
                return Row(
                  children: [
                    Expanded(child: title),
                    restore,
                    SizedBox(width: 8 * s),
                    purge,
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title,
                  SizedBox(height: 10 * s),
                  Row(children: [restore, SizedBox(width: 8 * s), purge]),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
