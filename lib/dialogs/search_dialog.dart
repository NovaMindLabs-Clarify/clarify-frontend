import 'package:flutter/material.dart';
import '../core/localization.dart';
import '../core/theme/design_tokens.dart';

/// Диалог поиска задач (Ctrl+F). Вынесено из DesktopPlannerScreen (P3.1,
/// docs/IMPROVEMENT_PLAN.md) — логика и разметка не менялись, только доступ
/// к состоянию родителя заменён на явные параметры функции.
void showSearchDialog({
  required BuildContext context,
  required String currentLang,
  required Color textColor,
  required Color textMuted,
  required List<Map<String, dynamic>> tasks,
  required void Function(Map<String, dynamic> task) onTaskSelected,
  required Widget Function({
    required Widget child,
    BorderRadius? borderRadius,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    Color? customColor,
  }) buildGlassContainer,
}) {
  final t = context.tokens;
  String query = '';
  showDialog(
    context: context,
    barrierColor: Colors.black.withOpacity(0.6),
    builder: (context) {
      return StatefulBuilder(builder: (context, setStateDialog) {
        final searchResults = query.isEmpty ? [] : tasks.where((t) =>
          (t['title']?.toString().toLowerCase().contains(query.toLowerCase()) ?? false) ||
          (t['note']?.toString().toLowerCase().contains(query.toLowerCase()) ?? false)
        ).toList();

        return Center(
          child: Material(
            color: Colors.transparent,
            child: SizedBox(
              width: 600,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  buildGlassContainer(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: TextField(
                      autofocus: true,
                      style: TextStyle(color: textColor, fontSize: 20),
                      decoration: InputDecoration(
                        hintText: "Поиск задач...".tr(currentLang),
                        hintStyle: TextStyle(color: textMuted),
                        border: InputBorder.none,
                        icon: Icon(Icons.search, color: t.accent, size: 28),
                      ),
                      onChanged: (val) => setStateDialog(() => query = val),
                    ),
                  ),
                  if (query.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    buildGlassContainer(
                      padding: const EdgeInsets.all(12),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 400),
                        child: searchResults.isEmpty
                          ? Padding(padding: const EdgeInsets.all(16), child: Text("Ничего не найдено".tr(currentLang), style: TextStyle(color: textMuted)))
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: searchResults.length,
                              itemBuilder: (context, index) {
                                final task = searchResults[index];
                                return ListTile(
                                  title: Text(task['title'] ?? '', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                                  subtitle: task['note'] != null ? Text(task['note'], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: textMuted)) : null,
                                  trailing: Icon(Icons.arrow_forward_ios, size: 14, color: t.accent),
                                  onTap: () {
                                    Navigator.pop(context);
                                    onTaskSelected(task);
                                  },
                                );
                              },
                            ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      });
    },
  );
}
