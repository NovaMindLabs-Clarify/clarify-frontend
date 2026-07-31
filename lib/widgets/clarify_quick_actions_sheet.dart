import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/localization.dart';
import '../core/theme/design_tokens.dart';
import 'clarify_glass.dart';
import 'clarify_surface.dart';

/// Быстрые действия по тапу на бейдж "гниющей" задачи — раньше бейдж был
/// чисто информационным, без единого действия, что рискует со временем
/// превратиться в фоновый шум, который глаз перестаёт замечать (тот же
/// эффект, что у любого пассивного баннера). Тап открывает три готовых
/// действия вместо обычного полного редактирования.
void showTaskRotQuickActions({
  required BuildContext context,
  required bool isDark,
  required String currentLang,
  required VoidCallback onDoToday,
  required VoidCallback onClearDeadline,
  required VoidCallback onDelete,
}) {
  final t = isDark ? ClarifyTokens.dark : ClarifyTokens.light;

  Widget row({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(ClarifyRadius.sm),
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color ?? t.text),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: color ?? t.text,
              ),
            ),
          ],
        ),
      ),
    );
  }

  final content = Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Что делаем с задачей?'.tr(currentLang),
        style: TextStyle(color: t.text2, fontSize: 13, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      row(
        icon: LucideIcons.calendarCheck,
        label: 'Сделать сегодня'.tr(currentLang),
        onTap: onDoToday,
      ),
      Divider(color: t.border, height: 1),
      row(
        icon: LucideIcons.calendarX,
        label: 'Снять дедлайн'.tr(currentLang),
        onTap: onClearDeadline,
      ),
      Divider(color: t.border, height: 1),
      row(
        icon: LucideIcons.trash2,
        label: 'Удалить'.tr(currentLang),
        color: t.danger,
        onTap: onDelete,
      ),
    ],
  );

  showClarifyResponsiveSurface(
    context: context,
    builder: (context) {
      if (isClarifyDialogMobile(context)) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.of(context).padding.bottom + 20),
          child: content,
        );
      }
      return Center(
        child: Material(
          color: Colors.transparent,
          child: ClarifyGlass(
            borderRadius: ClarifyRadius.dialogShell,
            padding: const EdgeInsets.all(20),
            child: SizedBox(width: 300, child: content),
          ),
        ),
      );
    },
  );
}
