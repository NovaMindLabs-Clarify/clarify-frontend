import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/clarify_date_format.dart';
import '../core/config.dart';
import '../core/localization.dart';
import '../core/tags.dart';
import '../core/theme/design_tokens.dart';

enum _ActivityPeriod { week, month, year }

/// Раздел "Статистика". Вынесено из DesktopPlannerScreen (P3.1,
/// docs/IMPROVEMENT_PLAN.md) — логика и разметка не менялись, только доступ
/// к состоянию родителя заменён на явные параметры конструктора.
class StatisticsDashboard extends StatefulWidget {
  final List<Map<String, dynamic>> tasks;
  final List<Map<String, dynamic>> workspaces;
  final String currentLang;
  final Color textColor;
  final Color textMuted;
  final bool Function(Map<String, dynamic> task) isOverdue;
  final DateTime? Function(String dateStr) parseDate;
  final Color Function(String? priority) getPriorityColor;
  final Widget Function({
    required Widget child,
    BorderRadius? borderRadius,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    Color? customColor,
  }) buildGlassContainer;

  /// Сколько задач в базе ВСЕГО — спрошено у сервера (B3).
  ///
  /// null означает «неизвестно»: связи нет либо запрос не прошёл. Тогда панель
  /// показывает, сколько задач загружено, и честно так и подписывает — вместо
  /// того чтобы выдавать окно за всю базу.
  final int? totalInBase;

  const StatisticsDashboard({
    super.key,
    required this.tasks,
    required this.workspaces,
    required this.currentLang,
    required this.textColor,
    required this.textMuted,
    required this.isOverdue,
    required this.parseDate,
    required this.getPriorityColor,
    required this.buildGlassContainer,
    this.totalInBase,
  });

  @override
  State<StatisticsDashboard> createState() => _StatisticsDashboardState();
}

class _StatisticsDashboardState extends State<StatisticsDashboard> {
  // keepScrollOffset: false — иначе Flutter восстанавливает через PageStorage
  // прошлую позицию скролла этого раздела (при переключении между пунктами
  // сайдбара сюда назад), и страница открывается не с верха, а с того места,
  // где был скролл в прошлый раз.
  final _scrollController = ScrollController(keepScrollOffset: false);
  _ActivityPeriod _period = _ActivityPeriod.week;

  /// Посчитанные числа и то, для чего они посчитаны.
  ///
  /// Пересчитываем, только когда пришёл ДРУГОЙ список задач (TaskCache всегда
  /// отдаёт новый список — сравнения по ссылке достаточно) или сменился
  /// календарный день: от «сегодня» зависят просрочка, серия и график
  /// активности, и панель, открытая через полночь, иначе врала бы.
  _DashboardStats? _stats;
  List<Map<String, dynamic>>? _statsSource;
  DateTime? _statsDay;

  _DashboardStats _statsFor(DateTime now) {
    final day = DateTime(now.year, now.month, now.day);
    final cached = _stats;
    if (cached != null &&
        identical(_statsSource, widget.tasks) &&
        _statsDay == day) {
      return cached;
    }
    final fresh = _DashboardStats.compute(
      tasks: widget.tasks,
      now: now,
      isOverdue: widget.isOverdue,
      priorityOrder: _priorityOrder,
    );
    _stats = fresh;
    _statsSource = widget.tasks;
    _statsDay = day;
    return fresh;
  }

  static const _priorityOrder = ['red', 'orange', 'blue', 'gray'];
  static const _priorityLabelKeys = {'red': 'Срочный', 'orange': 'Важный', 'blue': 'Обычный', 'gray': 'Низкий'};
  static const _monthShortKeys = ['Янв', 'Фев', 'Мар', 'Апр', 'Май', 'Июн', 'Июл', 'Авг', 'Сен', 'Окт', 'Ноя', 'Дек'];
  static const _weekdayShortKeys = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workspaces = widget.workspaces;
    final currentLang = widget.currentLang;
    final textColor = widget.textColor;
    final textMuted = widget.textMuted;
    final getPriorityColor = widget.getPriorityColor;
    final buildGlassContainer = widget.buildGlassContainer;
    final t = context.tokens;
    final now = DateTime.now();

    // Все счётчики считаются ОДНИМ проходом и кэшируются (см. _DashboardStats).
    // Раньше build() проходил по списку задач шестнадцать раз: девять циклов
    // подряд плюс семь вызовов dayLoadMinutes на «перегруженные дни», и всё это
    // заново при каждой перерисовке — включая перерисовку от любого события
    // realtime. Именно это в аудите (B3) названо «приложение начнёт думать на
    // пустом месте».
    final s = _statsFor(now);

    final doneCount = s.done;
    final pendingCount = s.pending;
    final overdueCount = s.overdue;
    final noDateCount = s.noDate;
    final rotCount = s.rot;
    final rescheduleCount = s.reschedule;
    final overloadedDaysCount = s.overloadedDays;

    final activityBuckets = switch (_period) {
      _ActivityPeriod.week => s.weekBuckets,
      _ActivityPeriod.month => s.monthBuckets,
      _ActivityPeriod.year => s.yearBuckets,
    };
    final activityTotal = activityBuckets.fold<int>(0, (a, b) => a + b);
    final activityLabelKey = switch (_period) {
      _ActivityPeriod.week => 'Выполнено за 7 дней',
      _ActivityPeriod.month => 'Выполнено за 30 дней',
      _ActivityPeriod.year => 'Выполнено за 12 месяцев',
    };

    final onTimeRatePercent = s.onTimePercent;
    final streak = s.streak;

    final projectTotal = s.projectTotal;
    final projectDone = s.projectDone;
    final sortedProjectTags = projectTotal.keys.toList()..sort((a, b) => projectTotal[b]!.compareTo(projectTotal[a]!));

    final priorityCount = s.priorityCount;
    final maxPriorityCount = priorityCount.values.isEmpty ? 0 : priorityCount.values.reduce((a, b) => a > b ? a : b);
    final totalPrioritized = priorityCount.values.fold<int>(0, (a, b) => a + b);

    final teamTotal = s.teamTotal;
    final teamDone = s.teamDone;
    final sortedWorkspaces = [...workspaces]..sort((a, b) => (teamTotal[b['id']] ?? 0).compareTo(teamTotal[a['id']] ?? 0));

    final weekdayCounts = s.weekdayCounts;
    final maxWeekdayCount = weekdayCounts.reduce((a, b) => a > b ? a : b);
    final totalWeekdayCount = weekdayCounts.fold<int>(0, (a, b) => a + b);

    Widget buildLegendItem(String title, Color color, int count) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(width: 14, height: 14, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(
              child: Text("${title.tr(currentLang)}: ", maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: textMuted, fontSize: 14)),
            ),
            Text("$count", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      );
    }

    Widget buildKpiCard(String titleKey, String value) {
      return Expanded(
        child: buildGlassContainer(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titleKey.tr(currentLang), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: textMuted, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Unbounded', fontSize: 48, fontWeight: FontWeight.w700, color: t.accent, fontFeatures: const [FontFeature.tabularFigures()])),
            ],
          ),
        ),
      );
    }

    Widget buildBar(double fraction, Color color) {
      return Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(ClarifyRadius.sm),
          child: Stack(
            children: [
              Container(height: 10, color: t.surfaceSunken),
              FractionallySizedBox(widthFactor: fraction.clamp(0.0, 1.0), child: Container(height: 10, color: color)),
            ],
          ),
        ),
      );
    }

    Widget buildCountRow(String label, Color color, int value, int maxValue) {
      final fraction = maxValue == 0 ? 0.0 : value / maxValue;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(width: 100, child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w600))),
            buildBar(fraction, color),
            const SizedBox(width: 10),
            SizedBox(width: 30, child: Text("$value", textAlign: TextAlign.right, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13))),
          ],
        ),
      );
    }

    Widget buildProgressRow(String label, Color color, int done, int total) {
      final fraction = total == 0 ? 0.0 : done / total;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(width: 100, child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w600))),
            buildBar(fraction, color),
            const SizedBox(width: 10),
            SizedBox(width: 50, child: Text("$done/$total", textAlign: TextAlign.right, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13))),
          ],
        ),
      );
    }

    Widget buildPeriodPill(String labelKey, _ActivityPeriod value) {
      final selected = _period == value;
      return InkWell(
        borderRadius: BorderRadius.circular(ClarifyRadius.pill),
        onTap: () => setState(() => _period = value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? t.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(ClarifyRadius.pill),
            border: Border.all(color: selected ? t.accent.withValues(alpha: 0.4) : t.border),
          ),
          child: Text(labelKey.tr(currentLang), style: TextStyle(color: selected ? t.accent : t.text2, fontSize: 13, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
        ),
      );
    }

    Widget buildHealthRow(IconData icon, String label, String detail, int count) {
      final ok = count == 0;
      final color = ok ? t.success : t.warning;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Icon(ok ? LucideIcons.check : icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w600)),
                  Text(detail, style: TextStyle(color: textMuted, fontSize: 12)),
                ],
              ),
            ),
            Text('$count', style: TextStyle(fontFamily: 'Unbounded', fontSize: 20, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      );
    }

    Widget buildHeatCell(String label, int count, int maxCount) {
      final intensity = maxCount == 0 ? 0.0 : count / maxCount;
      final bg = Color.lerp(t.surfaceSunken, t.accent, intensity.clamp(0.0, 1.0))!;
      final fg = intensity > 0.55 ? t.onAccent : textColor;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            children: [
              Text(label, style: TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(ClarifyRadius.sm)),
                  alignment: Alignment.center,
                  child: Text("$count", style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              buildKpiCard(activityLabelKey, "$activityTotal"),
              const SizedBox(width: 16),
              // Число от сервера, если оно есть: клиент грузит окно и о
              // задачах за его пределами не знает. Нет связи — показываем
              // загруженное и меняем подпись, а не молчим.
              buildKpiCard(
                widget.totalInBase == null ? "Задач загружено" : "Всего задач в базе",
                "${widget.totalInBase ?? s.total}",
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              buildKpiCard("% выполнено в срок", onTimeRatePercent == null ? "—" : "$onTimeRatePercent%"),
              const SizedBox(width: 16),
              buildKpiCard("Серия дней подряд", "$streak"),
            ],
          ),
          const SizedBox(height: 24),

          buildGlassContainer(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Здоровье недели".tr(currentLang), style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                buildHealthRow(
                  LucideIcons.archive,
                  "Гниющие задачи".tr(currentLang),
                  "${"Без движения дольше".tr(currentLang)} ${AppConfig.taskRotDays} ${"дн.".tr(currentLang)}",
                  rotCount,
                ),
                buildHealthRow(
                  LucideIcons.history,
                  "Часто переносятся".tr(currentLang),
                  "${"Перенесены".tr(currentLang)} ${AppConfig.rescheduleWarningCount}+ ${"раз".tr(currentLang)}",
                  rescheduleCount,
                ),
                buildHealthRow(
                  LucideIcons.triangleAlert,
                  "Перегруженные дни".tr(currentLang),
                  "Из ближайших 7".tr(currentLang),
                  overloadedDaysCount,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          buildGlassContainer(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Статус задач".tr(currentLang), style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    // На узких телефонных экранах пирог+легенда в один Row не
                    // помещаются (150-180px на легенду не хватает даже с
                    // эллипсисом) — переключаемся на вертикальную раскладку.
                    final narrow = constraints.maxWidth < 360;
                    final pieSize = narrow ? 150.0 : 180.0;
                    final chart = SizedBox(
                      height: pieSize,
                      width: pieSize,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 4,
                          centerSpaceRadius: narrow ? 40 : 50,
                          sections: [
                            if (doneCount > 0) PieChartSectionData(color: t.success, value: doneCount.toDouble(), title: '$doneCount', radius: 40, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, shadows: [Shadow(color: Colors.black45, blurRadius: 4)])),
                            if (pendingCount > 0) PieChartSectionData(color: t.accent, value: pendingCount.toDouble(), title: '$pendingCount', radius: 40, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, shadows: [Shadow(color: Colors.black45, blurRadius: 4)])),
                            if (overdueCount > 0) PieChartSectionData(color: t.danger, value: overdueCount.toDouble(), title: '$overdueCount', radius: 40, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, shadows: [Shadow(color: Colors.black45, blurRadius: 4)])),
                            if (noDateCount > 0) PieChartSectionData(color: Colors.grey.shade500, value: noDateCount.toDouble(), title: '$noDateCount', radius: 40, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, shadows: [Shadow(color: Colors.black45, blurRadius: 4)])),
                          ],
                        ),
                      ),
                    );
                    final legend = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        buildLegendItem('Сделано', t.success, doneCount),
                        buildLegendItem('В процессе', t.accent, pendingCount),
                        buildLegendItem('Просрочено', t.danger, overdueCount),
                        buildLegendItem('Без срока', Colors.grey.shade500, noDateCount),
                      ],
                    );
                    if (narrow) {
                      return Column(
                        children: [
                          Center(child: chart),
                          const SizedBox(height: 20),
                          legend,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        chart,
                        const SizedBox(width: 40),
                        Expanded(child: legend),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          buildGlassContainer(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final title = Text("Активность (последние 7 дней)".tr(currentLang), style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold));
                    final pills = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        buildPeriodPill('Неделя', _ActivityPeriod.week),
                        const SizedBox(width: 6),
                        buildPeriodPill('Месяц', _ActivityPeriod.month),
                        const SizedBox(width: 6),
                        buildPeriodPill('Год', _ActivityPeriod.year),
                      ],
                    );
                    // Заголовок + переключатель периода в один Row не
                    // помещаются на узких телефонах — переносим переключатель
                    // на отдельную строку.
                    if (constraints.maxWidth < 360) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          title,
                          const SizedBox(height: 12),
                          pills,
                        ],
                      );
                    }
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [title, pills],
                    );
                  },
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: (activityBuckets.reduce((a, b) => a > b ? a : b) + 2).toDouble(),
                      barTouchData: BarTouchData(enabled: false),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (double value, TitleMeta meta) {
                              final idx = value.toInt();
                              String label;
                              if (_period == _ActivityPeriod.year) {
                                final monthOffset = 11 - idx;
                                final monthIndex0 = (((now.month - 1) - monthOffset) % 12 + 12) % 12;
                                label = _monthShortKeys[monthIndex0].tr(currentLang);
                              } else {
                                final bucketCount = activityBuckets.length;
                                if (_period == _ActivityPeriod.month && idx % 5 != 0) return const SizedBox.shrink();
                                final date = now.subtract(Duration(days: bucketCount - 1 - idx));
                                label = "${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}";
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(label, style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      barGroups: List.generate(activityBuckets.length, (index) {
                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: activityBuckets[index].toDouble(),
                              color: index == activityBuckets.length - 1 ? t.accent : t.accent.withValues(alpha: 0.4),
                              width: _period == _ActivityPeriod.week ? 22 : (_period == _ActivityPeriod.month ? 7 : 16),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (sortedProjectTags.isNotEmpty) ...[
            const SizedBox(height: 24),
            buildGlassContainer(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Активность по проектам".tr(currentLang), style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  ...sortedProjectTags.map((tag) => buildProgressRow(tag, t.tagPalette[tag.hashCode.abs() % t.tagPalette.length], projectDone[tag] ?? 0, projectTotal[tag]!)),
                ],
              ),
            ),
          ],

          if (totalPrioritized > 0) ...[
            const SizedBox(height: 24),
            buildGlassContainer(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("По приоритетам".tr(currentLang), style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  ..._priorityOrder.map((p) => buildCountRow(_priorityLabelKeys[p]!.tr(currentLang), getPriorityColor(p), priorityCount[p]!, maxPriorityCount)),
                ],
              ),
            ),
          ],

          if (sortedWorkspaces.isNotEmpty) ...[
            const SizedBox(height: 24),
            buildGlassContainer(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("По командам".tr(currentLang), style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  ...sortedWorkspaces.map((ws) {
                    final wsId = ws['id'] as int;
                    return buildProgressRow(ws['name'].toString(), t.tagPalette[wsId % t.tagPalette.length], teamDone[wsId] ?? 0, teamTotal[wsId] ?? 0);
                  }),
                ],
              ),
            ),
          ],

          if (totalWeekdayCount > 0) ...[
            const SizedBox(height: 24),
            buildGlassContainer(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Активность по дням недели".tr(currentLang), style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(children: List.generate(7, (i) => buildHeatCell(_weekdayShortKeys[i].tr(currentLang), weekdayCounts[i], maxWeekdayCount))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Все числа панели, посчитанные одним проходом по списку задач.
///
/// Раньше каждое из них считалось своим циклом прямо в build(): девять циклов
/// плюс семь вызовов dayLoadMinutes ради «перегруженных дней» — шестнадцать
/// полных проходов, и заново при каждой перерисовке. На телефоне это заметно.
///
/// Считать те же правила в SQL (как предлагает B3 аудита) я сознательно не
/// стал: условия здесь намеренно зеркалят buildRotBadge/buildRescheduleBadge,
/// чтобы цифра в сводке не расходилась со значком на самой задаче, и третья
/// копия тех же правил на другом языке рассинхронизировалась бы молча — ровно
/// так, как 05.09.2026 разъехались четыре копии «дедлайна задачи». Выигрыш в
/// скорости даёт кэширование, а не перенос.
class _DashboardStats {
  final int total;
  final int done;
  final int pending;
  final int overdue;
  final int noDate;
  final int rot;
  final int reschedule;
  final int overloadedDays;
  final List<int> weekBuckets;
  final List<int> monthBuckets;
  final List<int> yearBuckets;
  final int? onTimePercent;
  final int streak;
  final Map<String, int> projectTotal;
  final Map<String, int> projectDone;
  final Map<String, int> priorityCount;
  final Map<int, int> teamTotal;
  final Map<int, int> teamDone;
  final List<int> weekdayCounts;

  const _DashboardStats({
    required this.total,
    required this.done,
    required this.pending,
    required this.overdue,
    required this.noDate,
    required this.rot,
    required this.reschedule,
    required this.overloadedDays,
    required this.weekBuckets,
    required this.monthBuckets,
    required this.yearBuckets,
    required this.onTimePercent,
    required this.streak,
    required this.projectTotal,
    required this.projectDone,
    required this.priorityCount,
    required this.teamTotal,
    required this.teamDone,
    required this.weekdayCounts,
  });

  static _DashboardStats compute({
    required List<Map<String, dynamic>> tasks,
    required DateTime now,
    required bool Function(Map<String, dynamic>) isOverdue,
    required List<String> priorityOrder,
  }) {
    int done = 0, pending = 0, overdue = 0, noDate = 0;
    int rot = 0, reschedule = 0;
    int onTimeDone = 0, consideredForOnTime = 0;

    final weekBuckets = List.filled(7, 0);
    final monthBuckets = List.filled(30, 0);
    final yearBuckets = List.filled(12, 0);
    final weekdayCounts = List.filled(7, 0);

    final projectTotal = <String, int>{};
    final projectDone = <String, int>{};
    final priorityCount = <String, int>{for (final p in priorityOrder) p: 0};
    final teamTotal = <int, int>{};
    final teamDone = <int, int>{};
    final completedDays = <DateTime>{};
    // Нагрузка по датам копится здесь же, вместо семи отдельных проходов
    // dayLoadMinutes по одному на каждый из ближайших дней.
    final loadByDate = <String, int>{};

    final today = DateTime(now.year, now.month, now.day);

    for (final task in tasks) {
      final isDone = task['is_completed'] == true;
      final rawDue = task['due_date'];
      final hasDue = rawDue != null && rawDue.toString().isNotEmpty;

      // --- статус ---
      if (isDone) {
        done++;
      } else if (!hasDue) {
        noDate++;
      } else if (isOverdue(task)) {
        overdue++;
      } else {
        pending++;
      }

      // --- гниение и переносы (зеркалят значки на карточке) ---
      if (!isDone) {
        if (!hasDue || isOverdue(task)) {
          final createdAt = DateTime.tryParse(task['created_at']?.toString() ?? '');
          if (createdAt != null && now.difference(createdAt).inDays >= AppConfig.taskRotDays) rot++;
        }
        final rescheduled = task['reschedule_count'] as int?;
        if (rescheduled != null && rescheduled >= AppConfig.rescheduleWarningCount) reschedule++;

        // --- нагрузка дня (то же условие, что в dayLoadMinutes) ---
        if (hasDue && task['parent_id'] == null) {
          final minutes = task['duration_minutes'];
          if (minutes is int) {
            loadByDate[rawDue.toString()] = (loadByDate[rawDue.toString()] ?? 0) + minutes;
          }
        }
      }

      // --- разбивка по тегам ---
      for (final tag in parseTagsString(task['tags'])) {
        projectTotal[tag] = (projectTotal[tag] ?? 0) + 1;
        if (isDone) projectDone[tag] = (projectDone[tag] ?? 0) + 1;
      }

      // --- разбивка по приоритетам ---
      final p = task['priority']?.toString();
      if (p != null && priorityCount.containsKey(p)) priorityCount[p] = priorityCount[p]! + 1;

      // --- разбивка по командам ---
      final rawWsId = task['workspace_id'];
      if (rawWsId != null) {
        final wsId = rawWsId is int ? rawWsId : int.tryParse(rawWsId.toString());
        if (wsId != null) {
          teamTotal[wsId] = (teamTotal[wsId] ?? 0) + 1;
          if (isDone) teamDone[wsId] = (teamDone[wsId] ?? 0) + 1;
        }
      }

      if (!isDone) continue;

      // --- всё дальнейшее только про выполненные ---
      final completedAt = task['completed_at'] != null
          ? DateTime.tryParse(task['completed_at'].toString())
          : null;

      if (completedAt != null) {
        completedDays.add(DateTime(completedAt.year, completedAt.month, completedAt.day));
        weekdayCounts[completedAt.weekday - 1]++;
      }

      // % в срок — только там, где известны и дедлайн, и момент выполнения.
      // Старые завершения без completed_at честно исключаются, а не
      // подставляются произвольным моментом.
      if (completedAt != null) {
        final deadline = taskDeadline(task);
        if (deadline != null) {
          consideredForOnTime++;
          if (!completedAt.isAfter(deadline)) onTimeDone++;
        }
      }

      // Момент фактического выполнения: completed_at, а для задач, отмеченных
      // до появления этой колонки, приближаем по дедлайну — иначе старая
      // история пропала бы из графика активности разом.
      final effective = completedAt ?? taskDueDate(task);
      if (effective == null) continue;

      final monthDiff = (now.year - effective.year) * 12 + (now.month - effective.month);
      if (monthDiff >= 0 && monthDiff < 12) yearBuckets[11 - monthDiff]++;

      final dayDiff = today
          .difference(DateTime(effective.year, effective.month, effective.day))
          .inDays;
      if (dayDiff >= 0 && dayDiff < 7) weekBuckets[6 - dayDiff]++;
      if (dayDiff >= 0 && dayDiff < 30) monthBuckets[29 - dayDiff]++;
    }

    // Серия дней подряд: сегодняшний день может быть ещё не закрыт, поэтому
    // отсутствие отметок за сегодня серию не обнуляет.
    int streak = 0;
    var cursor = today;
    if (!completedDays.contains(cursor)) cursor = cursor.subtract(const Duration(days: 1));
    while (completedDays.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    int overloaded = 0;
    for (var i = 0; i < 7; i++) {
      final d = today.add(Duration(days: i));
      final key = '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
      if ((loadByDate[key] ?? 0) >= AppConfig.dailyLoadWarningMinutes) overloaded++;
    }

    return _DashboardStats(
      total: tasks.length,
      done: done,
      pending: pending,
      overdue: overdue,
      noDate: noDate,
      rot: rot,
      reschedule: reschedule,
      overloadedDays: overloaded,
      weekBuckets: weekBuckets,
      monthBuckets: monthBuckets,
      yearBuckets: yearBuckets,
      onTimePercent: consideredForOnTime == 0
          ? null
          : ((onTimeDone / consideredForOnTime) * 100).round(),
      streak: streak,
      projectTotal: projectTotal,
      projectDone: projectDone,
      priorityCount: priorityCount,
      teamTotal: teamTotal,
      teamDone: teamDone,
      weekdayCounts: weekdayCounts,
    );
  }
}
