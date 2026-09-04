import 'package:flutter/material.dart';
import '../core/localization.dart';
import '../core/theme/design_tokens.dart';
import '../core/tags.dart';
import 'icon_picker_dialog.dart';
import 'clarify_illustrations.dart';

/// "Проекты" — отдельный полноэкранный раздел вместо инлайн-списка тег-папок
/// прямо в сайдбаре (тот разрастался вместе с числом проектов). Сами
/// авто-папки — как и раньше, значение поля tags у задачи, не отдельная
/// сущность (см. sidebar_menu.dart, ProjectKanbanBoard).
class ProjectsScreen extends StatelessWidget {
  final bool isDark;
  final String currentLang;
  final double scale;
  final List<Map<String, dynamic>> tasks;
  final Map<String, String> projectIconKeys;
  final void Function(String tag, String iconKey) onSetProjectIcon;
  final Map<String, int> projectColorKeys;
  final void Function(String tag, int colorIndex) onSetProjectColor;
  final void Function(String tag) onOpenProject;

  const ProjectsScreen({
    super.key,
    required this.isDark,
    required this.currentLang,
    required this.scale,
    required this.tasks,
    required this.projectIconKeys,
    required this.onSetProjectIcon,
    required this.projectColorKeys,
    required this.onSetProjectColor,
    required this.onOpenProject,
  });

  Future<void> _customize(BuildContext context, String tag, int fallbackColorIndex) async {
    final picked = await showProjectCustomizeDialog(
      context: context,
      isDark: isDark,
      currentLang: currentLang,
      currentIcon: projectIconKeys[tag],
      currentColorIndex: projectColorKeys[tag] ?? fallbackColorIndex,
    );
    if (picked != null) {
      onSetProjectIcon(tag, picked['icon']!);
      onSetProjectColor(tag, int.parse(picked['color']!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final s = scale;

    final sortedTags = collectAllTags(tasks);

    if (sortedTags.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32 * s),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClarifyIllustration(type: ClarifyIllustrationType.folderGlow, size: 64 * s),
              SizedBox(height: 16 * s),
              Text(
                'Проектов пока нет'.tr(currentLang),
                style: TextStyle(fontSize: 15 * s, fontWeight: FontWeight.w600, color: t.text2),
              ),
              SizedBox(height: 6 * s),
              Text(
                'Добавьте тег к задаче — папка появится автоматически'.tr(currentLang),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13 * s, color: t.text3),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      // Горизонтальные отступы те же, что у сетки календаря: без них карточки
      // упирались в сайдбар слева и обрезались краем окна справа.
      padding: EdgeInsets.fromLTRB(24 * s, 0, 24 * s, 24 * s),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 280 * s,
        mainAxisExtent: 76 * s,
        crossAxisSpacing: 16 * s,
        mainAxisSpacing: 16 * s,
      ),
      itemCount: sortedTags.length,
      itemBuilder: (context, index) {
        final tag = sortedTags[index];
        final fallbackColorIndex = tag.hashCode.abs() % t.tagPalette.length;
        final storedColorIndex = projectColorKeys[tag];
        final tagColor = storedColorIndex != null && storedColorIndex < t.tagPalette.length
            ? t.tagPalette[storedColorIndex]
            : t.tagPalette[fallbackColorIndex];
        final tagTasks = tasks
            .where((task) => parseTagsString(task['tags']).contains(tag) && task['parent_id'] == null)
            .toList();
        final total = tagTasks.length;
        final done = tagTasks.where((task) => task['is_completed'] == true).length;
        final icon = iconByKey(projectIconKeys[tag]);

        return Material(
          color: t.surface,
          borderRadius: BorderRadius.circular(ClarifyRadius.md),
          // Полоса прогресса идёт от края до края карточки — без обрезки она
          // вылезала бы за скруглённые углы.
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: BorderRadius.circular(ClarifyRadius.md),
            onTap: () => onOpenProject(tag),
            onLongPress: () => _customize(context, tag, fallbackColorIndex),
            onSecondaryTap: () => _customize(context, tag, fallbackColorIndex),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(ClarifyRadius.md),
                border: Border(left: BorderSide(color: tagColor, width: 3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16 * s, vertical: 14 * s),
                      child: Row(
                        children: [
                          Icon(icon, color: tagColor, size: 24 * s),
                          SizedBox(width: 12 * s),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  tag,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 15 * s, fontWeight: FontWeight.w700, color: t.text),
                                ),
                                SizedBox(height: 2 * s),
                                Text(
                                  '$done/$total ${'задач'.tr(currentLang)}',
                                  style: TextStyle(fontSize: 12.5 * s, color: t.text3),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // "47/51 задач" — это число, которое нужно читать; полоса
                  // даёт то же самое одним взглядом по всей сетке проектов
                  // сразу, не заставляя сравнивать дроби в уме.
                  if (total > 0)
                    SizedBox(
                      height: 3 * s,
                      child: LinearProgressIndicator(
                        value: done / total,
                        backgroundColor: t.surfaceSunken,
                        valueColor: AlwaysStoppedAnimation<Color>(tagColor),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
