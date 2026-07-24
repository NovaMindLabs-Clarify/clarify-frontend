import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../core/localization.dart';
import '../core/theme/design_tokens.dart';

/// Раздел "Статистика". Вынесено из DesktopPlannerScreen (P3.1,
/// docs/IMPROVEMENT_PLAN.md) — логика и разметка не менялись, только доступ
/// к состоянию родителя заменён на явные параметры конструктора.
class StatisticsDashboard extends StatefulWidget {
  final List<Map<String, dynamic>> tasks;
  final String currentLang;
  final Color textColor;
  final Color textMuted;
  final bool Function(Map<String, dynamic> task) isOverdue;
  final DateTime? Function(String dateStr) parseDate;
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
    required this.currentLang,
    required this.textColor,
    required this.textMuted,
    required this.isOverdue,
    required this.parseDate,
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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = widget.tasks;
    final currentLang = widget.currentLang;
    final textColor = widget.textColor;
    final textMuted = widget.textMuted;
    final isOverdue = widget.isOverdue;
    final parseDate = widget.parseDate;
    final buildGlassContainer = widget.buildGlassContainer;
    final t = context.tokens;
    final now = DateTime.now();
    List<int> weeklyStats = List.filled(7, 0);
    int totalDone = 0;

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

      if (task['is_completed'] == true && task['due_date'] != null) {
        final date = parseDate(task['due_date']);
        if (date != null) {
          final diff = now.difference(date).inDays;
          if (diff >= 0 && diff < 7) {
            weeklyStats[6 - diff]++;
            totalDone++;
          }
        }
      }
    }

    Widget buildLegendItem(String title, Color color, int count) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(width: 14, height: 14, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text("${title.tr(currentLang)}: ", style: TextStyle(color: textMuted, fontSize: 14)),
            Text("$count", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
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
              Expanded(
                child: buildGlassContainer(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Выполнено за 7 дней".tr(currentLang), style: TextStyle(color: textMuted, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text("$totalDone", style: TextStyle(fontFamily: 'Unbounded', fontSize: 48, fontWeight: FontWeight.w700, color: t.accent, fontFeatures: const [FontFeature.tabularFigures()])),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: buildGlassContainer(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Всего задач в базе".tr(currentLang), style: TextStyle(color: textMuted, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text("${tasks.length}", style: TextStyle(fontFamily: 'Unbounded', color: textColor, fontSize: 48, fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()])),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          buildGlassContainer(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Статус задач".tr(currentLang), style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                Row(
                  children: [
                    SizedBox(
                      height: 180,
                      width: 180,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 4,
                          centerSpaceRadius: 50,
                          sections: [
                            if (doneCount > 0) PieChartSectionData(color: t.success, value: doneCount.toDouble(), title: '$doneCount', radius: 40, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, shadows: [Shadow(color: Colors.black45, blurRadius: 4)])),
                            if (pendingCount > 0) PieChartSectionData(color: t.accent, value: pendingCount.toDouble(), title: '$pendingCount', radius: 40, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, shadows: [Shadow(color: Colors.black45, blurRadius: 4)])),
                            if (overdueCount > 0) PieChartSectionData(color: t.danger, value: overdueCount.toDouble(), title: '$overdueCount', radius: 40, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, shadows: [Shadow(color: Colors.black45, blurRadius: 4)])),
                            if (noDateCount > 0) PieChartSectionData(color: Colors.grey.shade500, value: noDateCount.toDouble(), title: '$noDateCount', radius: 40, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, shadows: [Shadow(color: Colors.black45, blurRadius: 4)])),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 40),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          buildLegendItem('Сделано', t.success, doneCount),
                          buildLegendItem('В процессе', t.accent, pendingCount),
                          buildLegendItem('Просрочено', t.danger, overdueCount),
                          buildLegendItem('Без срока', Colors.grey.shade500, noDateCount),
                        ],
                      ),
                    ),
                  ],
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
                Text("Активность (последние 7 дней)".tr(currentLang), style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 32),
                SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: (weeklyStats.reduce((a, b) => a > b ? a : b) + 2).toDouble(),
                      barTouchData: BarTouchData(enabled: false),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (double value, TitleMeta meta) {
                              final date = now.subtract(Duration(days: 6 - value.toInt()));
                              final dayStr = date.day.toString().padLeft(2, '0');
                              final monthStr = date.month.toString().padLeft(2, '0');
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text("$dayStr.$monthStr", style: TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
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
                      barGroups: List.generate(7, (index) {
                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: weeklyStats[index].toDouble(),
                              color: index == 6 ? t.accent : t.accent.withValues(alpha: 0.4),
                              width: 22,
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
        ],
      ),
    );
  }
}
