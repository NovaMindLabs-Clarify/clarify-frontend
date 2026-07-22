import 'package:flutter/material.dart';
import '../core/localization.dart';
import '../core/theme/design_tokens.dart';

class SidebarMenu extends StatelessWidget {
  final bool isDark;
  final double scale;
  final String currentLang;
  final String selectedMenu;
  final List<String> menuItems;
  final List<String> customFolders;
  final List<dynamic> workspaces;
  
  final Function(String) onMenuSelected;
  final VoidCallback onAddFolder;
  final Function(String) onDeleteFolder;
  final VoidCallback onAddWorkspace;
  final Function(int, String) onWorkspaceSelected;
  
  final Widget userAccountBlock;
  final Widget Function({required Widget child, BorderRadius? borderRadius, EdgeInsetsGeometry? margin, Color? customColor}) buildGlassContainer;

  const SidebarMenu({
    Key? key,
    required this.isDark,
    required this.scale,
    required this.currentLang,
    required this.selectedMenu,
    required this.menuItems,
    required this.customFolders,
    required this.workspaces,
    required this.onMenuSelected,
    required this.onAddFolder,
    required this.onDeleteFolder,
    required this.onAddWorkspace,
    required this.onWorkspaceSelected,
    required this.userAccountBlock,
    required this.buildGlassContainer,
  }) : super(key: key);

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
                      title: Text(item.tr(currentLang), style: TextStyle(fontSize: 16 * scale, fontWeight: item == selectedMenu ? FontWeight.bold : FontWeight.w600, color: item == selectedMenu ? t.accent : textColor)),
                      onTap: () => onMenuSelected(item), 
                    ),
                  )),
                  
                  SizedBox(height: 16 * scale),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 8 * scale),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("ПРОЕКТЫ".tr(currentLang), style: TextStyle(fontSize: 12 * scale, fontWeight: FontWeight.bold, color: textMuted, letterSpacing: 1.2)),
                        InkWell(
                          onTap: onAddFolder,
                          child: Icon(Icons.add, size: 20 * scale, color: textMuted)
                        ),
                      ],
                    ),
                  ),
                  
                  ...customFolders.map((folder) => Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 2 * scale),
                    child: ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12 * scale)),
                      selected: folder == selectedMenu,
                      selectedTileColor: highlightColor,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16 * scale),
                      leading: Icon(Icons.folder_outlined, size: 20 * scale, color: folder == selectedMenu ? t.accent : textMuted),
                      title: Text(folder, style: TextStyle(fontSize: 15 * scale, fontWeight: folder == selectedMenu ? FontWeight.bold : FontWeight.w600, color: folder == selectedMenu ? t.accent : textColor), overflow: TextOverflow.ellipsis),
                      onTap: () => onMenuSelected(folder),
                      onLongPress: () => onDeleteFolder(folder), 
                    ),
                  )),

                  SizedBox(height: 16 * scale),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 8 * scale),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("КОМАНДЫ".tr(currentLang), style: TextStyle(fontSize: 12 * scale, fontWeight: FontWeight.bold, color: textMuted, letterSpacing: 1.2)),
                        InkWell(
                          onTap: onAddWorkspace,
                          child: Icon(Icons.add_business, size: 20 * scale, color: textMuted)
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
                        leading: Icon(Icons.group_work_outlined, size: 20 * scale, color: selectedMenu == wsMenuKey ? wsColor : textMuted),
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