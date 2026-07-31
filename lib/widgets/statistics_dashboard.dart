import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/config.dart';
import '../core/localization.dart';
import '../core/tags.dart';
import '../core/theme/design_tokens.dart';
import 'clarify_day_load_warning.dart' show dayLoadMinutes;

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

  static const _priorityOrder = ['red', 'orange', 'blue', 'gray'];
  static const _priorityLabelKeys = {'red': 'Срочный', 'orange': 'Важный', 'blue': 'Обычный', 'gray': 'Низкий'};
  static const _monthShortKeys = ['Янв', 'Фев', 'Мар', 'Апр', 'Май', 'Июн', 'Июл', 'Авг', 'Сен', 'Окт', 'Ноя', 'Дек'];
  static const _weekdayShortKeys = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Момент фактического выполнения — новый completed_at, если есть; для
  // задач, отмеченных до появления этой колонки, приближаем по due_date,
  // чтобы старая история не пропадала из графика активности разом.
  DateTime? _effectiveCompletionDate(Map<String, dynamic> task) {
    final raw = task['completed_at'];
    if (raw != null) {
      final dt = DateTime.tryParse(raw.toString());
      if (dt != null) return dt;
    }
    if (task['due_date'] != null) return widget.parseDate(task['due_date'].toString());
    return null;
  }

  List<int> _activityBuckets(DateTime now) {
    final bucketCount = switch (_period) { _ActivityPeriod.week => 7, _ActivityPeriod.month => 30, _ActivityPeriod.year => 12 };
    final buckets = List.filled(bucketCount, 0);
    for (final task in widget.tasks) {
      if (task['is_completed'] != true) continue;
      final date = _effectiveCompletionDate(task);
      if (date == null) continue;
      if (_period == _ActivityPeriod.year) {
        final monthDiff = (now.year - date.year) * 12 + (now.month - date.month);
        if (monthDiff >= 0 && monthDiff < 12) buckets[11 - monthDiff]++;
      } else {
        final diff = DateTime(now.year, now.month, now.day).difference(DateTime(date.year, date.month, date.day)).inDays;
        if (diff >= 0 && diff < bucketCount) buckets[bucketCount - 1 - diff]++;
      }
    }
    return buckets;
  }

  @override
  Widget build(BuildContext context) {
    final tasks = widget.tasks;
    final workspaces = widget.workspaces;
    final currentLang = widget.currentLang;
    final textColor = widget.textColor;
    final textMuted = widget.textMuted;
    final isOverdue = widget.isOverdue;
    final parseDate = widget.parseDate;
    final getPriorityColor = widget.getPriorityColor;
    final buildGlassContainer = widget.buildGlassContainer;
    final t = context.tokens;
    final now = DateTime.now();

    int doneCount = 0;
    int pendingCount = 0;
    int overdueCount = 0;
    int noDateCount = 0;

    for (var task in tasks) {
      if (task['is_completed'] == true) {
        doneCount++;
      } else if (task['due_date'] == null || task['due_date'].toString().isEmpty) {
        noDateCount++;
      } else {
        if (isOverdue(task)) {
          overdueCount++;
        } else {
          pendingCount++;
        }
      }
    }

    // "Здоровье недели" — сводка по трём уже отслеживаемым по отдельным
    // задачам сигналам (значки гниения/переноса на карточках, предупреждение
    // о загрузке дня при планировании), сведённая в одно место: раньше их
    // можно было заметить только по одной задаче за раз, листая список, а не
    // как общую картину недели. Условия здесь намеренно зеркалят
    // buildRotBadge/buildRescheduleBadge (clarify_task_checkbox.dart) —
    // цифра в дайджесте не должна расходиться с тем, что показывает бейдж на
    // самой задаче.
    int rotCount = 0;
    int rescheduleCount = 0;
    for (final task in tasks) {
      if (task['is_completed'] == true) continue;
      if (task['due_date'] == null || isOverdue(task)) {
        final createdAt = DateTime.tryParse(task['created_at']?.toString() ?? '');
        if (createdAt != null && now.difference(createdAt).inDays >= AppConfig.taskRotDays) rotCount++;
      }
      final rescheduled = task['reschedule_count'] as int?;
      if (rescheduled != null && rescheduled >= AppConfig.rescheduleWarningCount) rescheduleCount++;
    }
    String fmtDate(DateTime d) => "${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}";
    final todayDateOnly = DateTime(now.year, now.month, now.day);
    final overloadedDaysCount = List.generate(7, (i) => todayDateOnly.add(Duration(days: i)))
        .where((d) => dayLoadMinutes(tasks, fmtDate(d)) >= AppConfig.dailyLoadWarningMinutes)
        .length;

    final activityBuckets = _activityBuckets(now);
    final activityTotal = activityBuckets.fold<int>(0, (a, b) => a + b);
    final activityLabelKey = switch (_period) {
      _ActivityPeriod.week => 'Выполнено за 7 дней',
      _ActivityPeriod.month => 'Выполнено за 30 дней',
      _ActivityPeriod.year => 'Выполнено за 12 месяцев',
    };

    // % выполнено в срок — считаем только по задачам, у которых есть и
    // due_date, и completed_at (старые завершения без completed_at честно
    // исключаем, а не подставляем произвольный момент).
    int onTimeDone = 0;
    int consideredForOnTime = 0;
    for (final task in tasks) {
      if (task['is_completed'] != true || task['due_date'] == null) continue;
      final completedAt = task['completed_at'] != null ? DateTime.tryParse(task['completed_at'].toString()) : null;
      if (completedAt == null) continue;
      final dueDate = parseDate(task['due_date'].toString());
      if (dueDate == null) continue;
      int hour = 23;
      int minute = 59;
      if (task['due_time'] != null && task['due_time'].toString().contains(':')) {
        final parts = task['due_time'].toString().split(':');
        hour = int.tryParse(parts[0]) ?? 23;
        minute = int.tryParse(parts[1]) ?? 59;
      }
      final dueDateTime = DateTime(dueDate.year, dueDate.month, dueDate.day, hour, minute);
      consideredForOnTime++;
      if (!completedAt.isAfter(dueDateTime)) onTimeDone++;
    }
    final int? onTimeRatePercent = consideredForOnTime == 0 ? null : ((onTimeDone / consideredForOnTime) * 100).round();

    // Серия дней подряд — по датам completed_at, допускаем, что сегодняшний
    // день ещё не закрыт (streak не обнуляется до полуночи, если вчера
    // что-то было выполнено, а сегодня пока ничего).
    final completedDays = <DateTime>{};
    for (final task in tasks) {
      if (task['is_completed'] != true || task['completed_at'] == null) continue;
      final dt = DateTime.tryParse(task['completed_at'].toString());
      if (dt == null) continue;
      completedDays.add(DateTime(dt.year, dt.month, dt.day));
    }
    int streak = 0;
    DateTime streakCursor = DateTime(now.year, now.month, now.day);
    if (!completedDays.contains(streakCursor)) streakCursor = streakCursor.subtract(const Duration(days: 1));
    while (completedDays.contains(streakCursor)) {
      streak++;
      streakCursor = streakCursor.subtract(const Duration(days: 1));
    }

    // Разбивка по проектам — тег может быть у задачи не один, считаем задачу
    // во всех её тегах сразу (как и ProjectsScreen).
    final Map<String, int> projectTotal = {};
    final Map<String, int> projectDone = {};
    for (final task in tasks) {
      for (final tag in parseTagsString(task['tags'])) {
        projectTotal[tag] = (projectTotal[tag] ?? 0) + 1;
        if (task['is_completed'] == true) projectDone[tag] = (projectDone[tag] ?? 0) + 1;
      }
    }
    final sortedProjectTags = projectTotal.keys.toList()..sort((a, b) => projectTotal[b]!.compareTo(projectTotal[a]!));

    // Разбивка по приоритетам.
    final Map<String, int> priorityCount = {for (final p in _priorityOrder) p: 0};
    for (final task in tasks) {
      final p = task['priority']?.toString();
      if (p != null && priorityCount.containsKey(p)) priorityCount[p] = priorityCount[p]! + 1;
    }
    final maxPriorityCount = priorityCount.values.isEmpty ? 0 : priorityCount.values.reduce((a, b) => a > b ? a : b);
    final totalPrioritized = priorityCount.values.fold<int>(0, (a, b) => a + b);

    // Разбивка по командам.
    final Map<int, int> teamTotal = {};
    final Map<int, int> teamDone = {};
    for (final task in tasks) {
      final rawWsId = task['workspace_id'];
      if (rawWsId == null) continue;
      final wsId = rawWsId is int ? rawWsId : int.tryParse(rawWsId.toString());
      if (wsId == null) continue;
      teamTotal[wsId] = (teamTotal[wsId] ?? 0) + 1;
      if (task['is_completed'] == true) teamDone[wsId] = (teamDone[wsId] ?? 0) + 1;
    }
    final sortedWorkspaces = [...workspaces]..sort((a, b) => (teamTotal[b['id']] ?? 0).compareTo(teamTotal[a['id']] ?? 0));

    // Тепловая карта по дням недели (1=Пн..7=Вс → индекс 0..6).
    final weekdayCounts = List.filled(7, 0);
    for (final task in tasks) {
      if (task['is_completed'] != true || task['completed_at'] == null) continue;
      final dt = DateTime.tryParse(task['completed_at'].toString());
      if (dt == null) continue;
      weekdayCounts[dt.weekday - 1]++;
    }
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
              buildKpiCard("Всего задач в базе", "${tasks.length}"),
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
                  "${"Из ближайших 7".tr(currentLang)}",
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
