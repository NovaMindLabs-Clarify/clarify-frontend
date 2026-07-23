import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/localization.dart';
import '../core/theme/design_tokens.dart';

/// Доска проекта — Не начато / В работе / Готово, вместо плоского списка,
/// который ничем не отличался от обычного тега (см. REDESIGN_V2_PLAN.md §3.5).
/// "Готово" считается по is_completed (реальное поле); "Не начато"/"В работе" —
/// локальный статус на устройстве (нет соответствующего поля в БД, поэтому
/// не синхронизируется между устройствами — это осознанное ограничение
/// этого прохода, не забытое).
class ProjectKanbanBoard extends StatelessWidget {
  final String projectName;
  final Color projectColor;
  final String currentLang;
  final double scale;
  final List<Map<String, dynamic>> tasks;
  final String Function(dynamic taskId) getLocalStatus;
  final void Function(dynamic taskId, String status) onSetLocalStatus;
  final Widget Function(Map<String, dynamic>) buildBoardTaskCardExpanded;
  final Widget Function({required Widget child, EdgeInsetsGeometry? margin, EdgeInsetsGeometry? padding, Color? customColor}) buildGlassContainer;

  const ProjectKanbanBoard({
    super.key,
    required this.projectName,
    required this.projectColor,
    required this.currentLang,
    required this.scale,
    required this.tasks,
    required this.getLocalStatus,
    required this.onSetLocalStatus,
    required this.buildBoardTaskCardExpanded,
    required this.buildGlassContainer,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    final done = tasks.where((task) => task['is_completed'] == true).toList();
    final active = tasks.where((task) => task['is_completed'] != true).toList();
    final todo = active.where((task) => getLocalStatus(task['id']) != 'doing').toList();
    final doing = active.where((task) => getLocalStatus(task['id']) == 'doing').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(24 * scale, 24 * scale, 24 * scale, 16 * scale),
          child: Row(
            children: [
              Container(width: 10 * scale, height: 10 * scale, decoration: BoxDecoration(color: projectColor, shape: BoxShape.circle)),
              SizedBox(width: 10 * scale),
              Text(projectName, style: TextStyle(fontFamily: 'Golos Text', fontSize: 22 * scale, fontWeight: FontWeight.w700, color: t.text)),
              SizedBox(width: 12 * scale),
              Text('${done.length}/${tasks.length}', style: TextStyle(fontSize: 14 * scale, color: t.text3, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24 * scale),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _column(context, 'Не начато', todo, canMoveRight: true, rightTaskStatus: 'doing')),
                SizedBox(width: 16 * scale),
                Expanded(child: _column(context, 'В работе', doing, canMoveLeft: true)),
                SizedBox(width: 16 * scale),
                Expanded(child: _column(context, 'Готово', done)),
              ],
            ),
          ),
        ),
        SizedBox(height: 24 * scale),
      ],
    );
  }

  Widget _column(BuildContext context, String title, List<Map<String, dynamic>> columnTasks, {bool canMoveRight = false, bool canMoveLeft = false, String? rightTaskStatus}) {
    final t = context.tokens;
    return buildGlassContainer(
      margin: EdgeInsets.only(bottom: 16 * scale),
      child: Padding(
        padding: EdgeInsets.all(12 * scale),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 6 * scale, vertical: 6 * scale),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title.tr(currentLang), style: TextStyle(fontSize: 13 * scale, fontWeight: FontWeight.bold, color: t.text2, letterSpacing: 0.3)),
                  Text('${columnTasks.length}', style: TextStyle(fontSize: 12 * scale, fontWeight: FontWeight.w700, color: t.text3)),
                ],
              ),
            ),
            Expanded(
              child: columnTasks.isEmpty
                  ? Center(child: Text('Пусто'.tr(currentLang), style: TextStyle(fontSize: 12.5 * scale, color: t.text3)))
                  : ListView.builder(
                      itemCount: columnTasks.length,
                      itemBuilder: (context, index) {
                        final task = columnTasks[index];
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (canMoveLeft)
                              IconButton(
                                icon: Icon(LucideIcons.chevronLeft, size: 16 * scale, color: t.text3),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                tooltip: 'Вернуть в «Не начато»'.tr(currentLang),
                                onPressed: () => onSetLocalStatus(task['id'], 'todo'),
                              ),
                            Expanded(child: buildBoardTaskCardExpanded(task)),
                            if (canMoveRight)
                              IconButton(
                                icon: Icon(LucideIcons.chevronRight, size: 16 * scale, color: t.text3),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                tooltip: 'Взять в работу'.tr(currentLang),
                                onPressed: () => onSetLocalStatus(task['id'], rightTaskStatus!),
                              ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
