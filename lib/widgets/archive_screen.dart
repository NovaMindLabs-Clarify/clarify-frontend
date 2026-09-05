import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/clarify_date_format.dart';
import '../core/localization.dart';
import '../core/theme/design_tokens.dart';
import 'clarify_button.dart';
import 'clarify_illustrations.dart';

/// История — выполненные задачи старше окна загрузки (вторая половина B3).
///
/// Приложение грузит окно: всё невыполненное плюс выполненное за последний год
/// (AppConfig.completedTasksWindowDays). Это правильно — тянуть тысячи задач
/// при каждом запуске и каждом realtime-событии ровно то, ради чего окно и
/// вводилось. Но задачи за его пределами становились недоступны ВООБЩЕ: они
/// есть в базе, а увидеть их нечем. С точки зрения человека это не
/// оптимизация, а пропажа его работы.
///
/// Поэтому отдельный раздел и отдельный запрос по требованию. Листается «по
/// последней показанной задаче», а не смещением: между запросами список
/// меняется, и страницы со смещением начали бы перекрываться или пропускать
/// задачи.
class ArchiveScreen extends StatefulWidget {
  final String currentLang;
  final double scale;

  /// Сколько дней покрывает окно загрузки — нужно только для честной подписи
  /// «здесь то, что старше N дней».
  final int windowDays;

  /// Грузит страницу истории старше указанного момента.
  final Future<List<Map<String, dynamic>>> Function(DateTime before) loadPage;

  /// Момент, с которого начинается история (граница окна).
  final DateTime Function() cutoff;

  const ArchiveScreen({
    super.key,
    required this.currentLang,
    required this.scale,
    required this.windowDays,
    required this.loadPage,
    required this.cutoff,
  });

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  final List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _reachedEnd = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMore(first: true);
  }

  /// Момент, старше которого просить следующую страницу.
  ///
  /// Для первой страницы — граница окна; дальше — время выполнения последней
  /// показанной задачи.
  DateTime get _before {
    if (_items.isEmpty) return widget.cutoff();
    final last = DateTime.tryParse(_items.last['completed_at']?.toString() ?? '');
    return last ?? widget.cutoff();
  }

  Future<void> _loadMore({bool first = false}) async {
    if (_loadingMore) return;
    setState(() {
      _error = null;
      if (first) {
        _loading = true;
      } else {
        _loadingMore = true;
      }
    });

    try {
      final page = await widget.loadPage(_before);
      if (!mounted) return;
      setState(() {
        _items.addAll(page);
        // Пустая страница — значит дальше ничего нет. Отдельного счётчика
        // «всего» не спрашиваем: он стоил бы лишнего запроса ради числа,
        // которое никому не нужно.
        _reachedEnd = page.isEmpty;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = _humanError(e);
      });
    }
  }

  /// Отличаем «нет связи» от «сломалось»: в первом случае повтор помогает, во
  /// втором обещать это нечестно.
  String _humanError(Object e) {
    final text = e.toString().toLowerCase();
    final offline = text.contains('timeout') ||
        text.contains('socket') ||
        text.contains('failed host lookup') ||
        text.contains('connection');
    return offline
        ? 'Нет связи с сервером. Проверьте интернет и повторите.'
        : 'Не удалось загрузить историю.';
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

  /// Масштаб по ТЕКУЩЕЙ ширине, а не по десктопному окну.
  ///
  /// Экран общий для ПК и телефона, а `scale` приходит из
  /// DesktopPlannerScreen, где считается как ширина/1920 и на телефоне упирается
  /// в нижнюю границу 0.4 — весь текст становился в два с половиной раза
  /// мельче задуманного. Та же ошибка была в корзине и поймана живым фидбеком
  /// 06.09.2026.
  double _scaleFor(double width) => width < 700 ? 1.0 : widget.scale;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final s = _scaleFor(MediaQuery.sizeOf(context).width);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClarifyIllustration(type: ClarifyIllustrationType.checklistFold, size: 84),
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
              onPressed: () => _loadMore(first: true),
            ),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClarifyIllustration(type: ClarifyIllustrationType.checklistFold, size: 84),
            const SizedBox(height: 18),
            Text(
              'В истории пока пусто'.tr(widget.currentLang),
              style: TextStyle(fontSize: 16 * s, fontWeight: FontWeight.w600, color: t.text2),
            ),
            const SizedBox(height: 7),
            Text(
              '${'Сюда попадают задачи, выполненные больше'.tr(widget.currentLang)} '
              '${widget.windowDays} ${_dayWord(widget.windowDays)} '
              '${'назад'.tr(widget.currentLang)}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13 * s, color: t.text3),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 20 * s, vertical: 12 * s),
      // +1 — строка «Загрузить ещё» либо подпись о конце списка.
      itemCount: _items.length + 1,
      itemBuilder: (context, index) {
        if (index == _items.length) return _footer(t, s);

        final task = _items[index];
        final completedAt = DateTime.tryParse(task['completed_at']?.toString() ?? '');
        return Container(
          padding: EdgeInsets.symmetric(vertical: 9 * s),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.border))),
          child: Row(
            children: [
              Icon(LucideIcons.check, size: 15 * s, color: t.success),
              SizedBox(width: 12 * s),
              Expanded(
                child: Text(
                  task['title']?.toString() ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5 * s,
                    color: t.text2,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: t.text3,
                  ),
                ),
              ),
              SizedBox(width: 12 * s),
              Text(
                completedAt == null ? '' : formatClarifyDate(completedAt),
                style: TextStyle(fontSize: 12.5 * s, color: t.text3),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _footer(ClarifyTokens t, double s) {
    if (_error != null) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 20 * s),
        child: Column(
          children: [
            Text(
              _error!.tr(widget.currentLang),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13 * s, color: t.text3),
            ),
            const SizedBox(height: 10),
            ClarifyButton(
              label: 'Повторить'.tr(widget.currentLang),
              icon: LucideIcons.refreshCw,
              scale: s,
              onPressed: _loadMore,
            ),
          ],
        ),
      );
    }

    if (_reachedEnd) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 20 * s),
        child: Center(
          child: Text(
            'Это вся история'.tr(widget.currentLang),
            style: TextStyle(fontSize: 12.5 * s, color: t.text3),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16 * s),
      child: Center(
        child: ClarifyButton(
          label: 'Загрузить ещё'.tr(widget.currentLang),
          icon: LucideIcons.chevronDown,
          scale: s,
          loading: _loadingMore,
          onPressed: _loadingMore ? null : _loadMore,
        ),
      ),
    );
  }
}
