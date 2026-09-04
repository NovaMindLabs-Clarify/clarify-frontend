import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../widgets/clarify_surface.dart';
import '../widgets/clarify_sparkle_burst.dart';
import '../widgets/clarify_illustrations.dart';
import '../core/localization.dart';
import '../core/theme/design_tokens.dart';

/// "Пульс команды" — сводка за сегодня по воркспейсу. Вынесено из
/// DesktopPlannerScreen (P3.1, docs/IMPROVEMENT_PLAN.md) — логика и разметка
/// не менялись, только доступ к состоянию родителя заменён на явные
/// параметры функции.

Widget _buildStatCard(String title, String value, Color color, double scale, String currentLang, Color textColor) {
  return Container(
    padding: EdgeInsets.all(16 * scale),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16 * scale), border: Border.all(color: color.withValues(alpha: 0.3))),
    child: Column(
      children: [
        Text(value, style: TextStyle(fontSize: 32 * scale, fontWeight: FontWeight.w900, color: color)),
        SizedBox(height: 4 * scale),
        Text(title.tr(currentLang), style: TextStyle(fontSize: 12 * scale, fontWeight: FontWeight.bold, color: textColor)),
      ],
    ),
  );
}

void showTeamPulseDialog({
  required BuildContext context,
  required int wsId,
  required double scale,
  required String currentLang,
  required Color textColor,
  required Color textMuted,
  required List<Map<String, dynamic>> tasks,
  required Map<int, List<Map<String, dynamic>>> workspaceMembers,
  required String Function(DateTime date) formatDate,
  required Widget Function({
    required Widget child,
    BorderRadius? borderRadius,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    Color? customColor,
  }) buildGlassContainer,
}) {
  final t = context.tokens;
  final s = scale;
  final todayStr = formatDate(DateTime.now());

  // Фильтруем задачи текущей команды ТОЛЬКО на сегодня
  var wsTasks = tasks.where((t) => t['workspace_id'] == wsId && t['due_date'] == todayStr && t['parent_id'] == null).toList();

  int totalCompleted = wsTasks.where((t) => t['is_completed'] == true).length;
  int totalActive = wsTasks.length - totalCompleted;

  // Считаем вклад каждого (кто сколько закрыл)
  Map<String, int> heroStats = {};
  for (var t in wsTasks.where((t) => t['is_completed'] == true && t['assigned_to'] != null)) {
    String uid = t['assigned_to'].toString();
    heroStats[uid] = (heroStats[uid] ?? 0) + 1;
  }

  // Сортируем героев по количеству закрытых задач (по убыванию)
  var sortedHeroes = heroStats.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

  showClarifySurface(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    builder: (context) {
      return Center(
        child: Material(
          color: Colors.transparent,
          child: buildGlassContainer(
            borderRadius: ClarifyRadius.dialogShell,
            padding: EdgeInsets.all(32 * s),
            child: SizedBox(
              width: 400 * s,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(LucideIcons.heartPulse, color: t.accent, size: 28 * s),
                          SizedBox(width: 12 * s),
                          Text("Пульс команды".tr(currentLang), style: TextStyle(fontSize: 20 * s, fontWeight: FontWeight.w900, color: textColor)),
                        ],
                      ),
                      IconButton(icon: Icon(LucideIcons.x, color: textMuted), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  SizedBox(height: 24 * s),

                  Row(
                    children: [
                      Expanded(child: _buildStatCard("Закрыто", totalCompleted.toString(), t.success, s, currentLang, textColor)),
                      SizedBox(width: 16 * s),
                      Expanded(child: _buildStatCard("В работе", totalActive.toString(), t.accent, s, currentLang, textColor)),
                    ],
                  ),

                  if (sortedHeroes.isNotEmpty) ...[
                    SizedBox(height: 32 * s),
                    ClarifySparkleBurst(
                      trigger: true,
                      child: Align(alignment: Alignment.centerLeft, child: Text("🏆 ГЕРОИ ДНЯ:".tr(currentLang), style: TextStyle(fontWeight: FontWeight.w900, color: textMuted, fontSize: 12 * s, letterSpacing: 1.2))),
                    ),
                    SizedBox(height: 16 * s),
                    Column(
                      children: sortedHeroes.map((entry) {
                        var members = workspaceMembers[wsId] ?? [];
                        var member = members.firstWhere((m) => m['user_id'] == entry.key, orElse: () => <String, dynamic>{});
                        String name = member.isNotEmpty ? (member['full_name'] ?? 'Участник'.tr(currentLang)) : 'Кто-то'.tr(currentLang);
                        String initial = name[0].toUpperCase();

                        return Padding(
                          padding: EdgeInsets.only(bottom: 12 * s),
                          child: Row(
                            children: [
                              CircleAvatar(radius: 16 * s, backgroundColor: t.tagPalette[members.indexOf(member) % t.tagPalette.length], child: Text(initial, style: TextStyle(color: Colors.white, fontSize: 14 * s, fontWeight: FontWeight.bold))),
                              SizedBox(width: 12 * s),
                              Expanded(child: Text(name, style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 16 * s))),
                              Container(padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 6 * s), decoration: BoxDecoration(color: t.successSoft, borderRadius: BorderRadius.circular(16 * s)), child: Text("${entry.value} ${'задач'.tr(currentLang)}", style: TextStyle(color: t.success, fontWeight: FontWeight.w900, fontSize: 13 * s))),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ] else ...[
                    SizedBox(height: 32 * s),
                    ClarifyIllustration(type: ClarifyIllustrationType.trophyShine, size: 88 * s),
                    SizedBox(height: 16 * s),
                    Text("Пока никто ничего не выполнил.\nСамое время начать! 🚀".tr(currentLang), textAlign: TextAlign.center, style: TextStyle(color: textMuted, fontSize: 15 * s)),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
