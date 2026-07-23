import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/localization.dart';
import '../core/theme/design_tokens.dart';

class SidebarMenu extends StatelessWidget {
  final bool isDark;
  final double scale;
  final String currentLang;
  final String selectedMenu;
  final List<String> menuItems;
  final List<dynamic> workspaces;
  final List<Map<String, dynamic>> tasks;

  final Function(String) onMenuSelected;
  final VoidCallback onAddWorkspace;
  final Function(int, String) onWorkspaceSelected;
  
  final Widget userAccountBlock;
  final Widget Function({required Widget child, BorderRadius? borderRadius, EdgeInsetsGeometry? margin, Color? customColor}) buildGlassContainer;

  // Те же соответствия, что и в мобильном нижнем меню (REDESIGN_V3_PLAN.md §3.18/5.17) —
  // не изобретаем новый набор для десктопа.
  static const Map<String, IconData> _menuIcons = {
    'Мой день': LucideIcons.sun,
    'Следующие 7 дней': LucideIcons.calendarDays,
    'Все задачи': LucideIcons.listChecks,
    'Календарь': LucideIcons.calendar,
    'Входящие': LucideIcons.inbox,
    'Друзья': LucideIcons.userRound,
    'Сообщения': LucideIcons.messageCircle,
    'Статистика': LucideIcons.chartNoAxesColumn,
  };

  const SidebarMenu({
    Key? key,
    required this.isDark,
    required this.scale,
    required this.currentLang,
    required this.selectedMenu,
    required this.menuItems,
    required this.workspaces,
    required this.tasks,
    required this.onMenuSelected,
    required this.onAddWorkspace,
    required this.onWorkspaceSelected,
    required this.userAccountBlock,
    required this.buildGlassContainer,
  }) : super(key: key);

  List<String> _taskTags(Map<String, dynamic> task) {
    final raw = task['tags'];
    if (raw == null || raw.toString().trim().isEmpty) return const [];
    return raw.toString().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  List<String> get _projectTags {
    final tags = <String>{};
    for (final task in tasks) {
      tags.addAll(_taskTags(task));
    }
    final sorted = tags.toList()..sort();
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final textColor = t.text;
    final textMuted = t.text2;
    final highlightColor = t.accentSoft;

    return buildGlassContainer(
      borderRadius: const BorderRadius.only(topRight: Radius.circular(24), bottomRight: Radius.circular(24)),
      margin: EdgeInsets.zero,
      child: SizedBox(
        width: 300 * scale,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(28 * scale, 40 * scale, 24 * scale, 32 * scale), 
              child: Text("Clarify", style: TextStyle(fontSize: 24 * scale, fontWeight: FontWeight.w900, letterSpacing: -0.5, color: textColor))
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ...menuItems.map((item) => Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 4 * scale),
                    child: ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12 * scale)),
                      selected: item == selectedMenu,
                      selectedTileColor: highlightColor,
                      leading: Icon(_menuIcons[item] ?? LucideIcons.circle, size: 20 * scale, color: item == selectedMenu ? t.accent : textMuted),
                      title: Text(item.tr(currentLang), style: TextStyle(fontSize: 16 * scale, fontWeight: item == selectedMenu ? FontWeight.bold : FontWeight.w600, color: item == selectedMenu ? t.accent : textColor)),
                      onTap: () => onMenuSelected(item),
                    ),
                  )),

                  SizedBox(height: 16 * scale),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 8 * scale),
                    child: Text("ПРОЕКТЫ".tr(currentLang), style: TextStyle(fontSize: 12 * scale, fontWeight: FontWeight.bold, color: textMuted, letterSpacing: 1.2)),
                  ),

                  // Авто-папки по тегам — не отдельная сущность, которую заводят руками
                  // (REDESIGN_V3_PLAN.md §3.17/5.16): папка появляется сама, как только
                  // существует хотя бы одна задача с этим тегом.
                  ..._projectTags.map((tag) {
                    final tagColor = t.tagPalette[tag.hashCode.abs() % t.tagPalette.length];
                    final tagTasks = tasks.where((task) => _taskTags(task).contains(tag) && task['parent_id'] == null).toList();
                    final total = tagTasks.length;
                    final done = tagTasks.where((task) => task['is_completed'] == true).length;
                    final active = tag == selectedMenu;

                    return Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 2 * scale),
                      child: ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12 * scale)),
                        selected: active,
                        selectedTileColor: tagColor.withValues(alpha: 0.15),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16 * scale),
                        leading: Icon(LucideIcons.folder, size: 20 * scale, color: active ? tagColor : textMuted),
                        title: Text(tag, style: TextStyle(fontSize: 15 * scale, fontWeight: active ? FontWeight.bold : FontWeight.w600, color: active ? tagColor : textColor), overflow: TextOverflow.ellipsis),
                        trailing: total == 0
                            ? null
                            : Text('$done/$total', style: TextStyle(fontSize: 11.5 * scale, fontWeight: FontWeight.w700, color: active ? tagColor : textMuted)),
                        onTap: () => onMenuSelected(tag),
                      ),
                    );
                  }),

                  SizedBox(height: 16 * scale),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 8 * scale),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("КОМАНДЫ".tr(currentLang), style: TextStyle(fontSize: 12 * scale, fontWeight: FontWeight.bold, color: textMuted, letterSpacing: 1.2)),
                        InkWell(
                          onTap: onAddWorkspace,
                          child: Icon(LucideIcons.building2, size: 20 * scale, color: textMuted)
                        ),
                      ],
                    ),
                  ),

                  ...workspaces.map((ws) {
                    String wsName = ws['name'].toString();
                    String wsMenuKey = 'ws_${ws['id']}';
                    // Метка команды — из назначаемой палитры по id, а не зашитый системный цвет.
                    final wsColor = t.tagPalette[(ws['id'] as int) % t.tagPalette.length];

                    return Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 2 * scale),
                      child: ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12 * scale)),
                        selected: selectedMenu == wsMenuKey,
                        selectedTileColor: wsColor.withValues(alpha: 0.15),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16 * scale),
                        leading: Icon(LucideIcons.usersRound, size: 20 * scale, color: selectedMenu == wsMenuKey ? wsColor : textMuted),
                        title: Text(wsName, style: TextStyle(fontSize: 15 * scale, fontWeight: selectedMenu == wsMenuKey ? FontWeight.bold : FontWeight.w600, color: selectedMenu == wsMenuKey ? wsColor : textColor), overflow: TextOverflow.ellipsis),
                        onTap: () => onWorkspaceSelected(ws['id'] as int, wsMenuKey),
                      ),
                    );
                  }),
                ],
              ),
            ),
            userAccountBlock,
            SizedBox(height: 24 * scale), 
          ], 
        ),
      ),
    );
  }
}