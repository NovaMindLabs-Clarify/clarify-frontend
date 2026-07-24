import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/theme/design_tokens.dart';
import 'clarify_glass.dart';
import 'clarify_surface.dart';

/// Набор иконок для ручного выбора — авто-папкам проектов и командам не
/// назначаешь иконку по смыслу автоматически (имя задаёт пользователь),
/// поэтому даём выбрать из курируемого набора, а не все ~1500 иконок Lucide.
///
/// Ключ (не codePoint!) — то, что хранится в Hive/Supabase и потом ищется
/// здесь же. IconData.codePoint теперь помечен @mustBeConst в самом Flutter
/// (нужно для icon tree-shaking в release-сборках) — собрать IconData из
/// произвольного числа во время выполнения запрещено на уровне анализатора,
/// поэтому хранить можно только ключ на статически объявленную константу, не
/// сам codePoint.
const Map<String, IconData> kPickableProjectIcons = {
  'folder': LucideIcons.folder,
  'briefcase': LucideIcons.briefcase,
  'rocket': LucideIcons.rocket,
  'target': LucideIcons.target,
  'flag': LucideIcons.flag,
  'star': LucideIcons.star,
  'lightbulb': LucideIcons.lightbulb,
  'puzzle': LucideIcons.puzzle,
  'code': LucideIcons.code,
  'palette': LucideIcons.palette,
  'wrench': LucideIcons.wrench,
  'hammer': LucideIcons.hammer,
  'paintbrush': LucideIcons.paintbrush,
  'bookOpen': LucideIcons.bookOpen,
  'graduationCap': LucideIcons.graduationCap,
  'trophy': LucideIcons.trophy,
  'heart': LucideIcons.heart,
  'home': LucideIcons.home,
  'building2': LucideIcons.building2,
  'usersRound': LucideIcons.usersRound,
  'globe': LucideIcons.globe,
  'plane': LucideIcons.plane,
  'car': LucideIcons.car,
  'dumbbell': LucideIcons.dumbbell,
  'leaf': LucideIcons.leaf,
  'sun': LucideIcons.sun,
  'moon': LucideIcons.moon,
  'music': LucideIcons.music,
  'camera': LucideIcons.camera,
  'gamepad2': LucideIcons.gamepad2,
  'coffee': LucideIcons.coffee,
  'utensils': LucideIcons.utensils,
  'gift': LucideIcons.gift,
  'shoppingCart': LucideIcons.shoppingCart,
  'wallet': LucideIcons.wallet,
  'chartNoAxesColumn': LucideIcons.chartNoAxesColumn,
  'zap': LucideIcons.zap,
  'shieldCheck': LucideIcons.shieldCheck,
  'calendarDays': LucideIcons.calendarDays,
  'sparkles': LucideIcons.sparkles,
};

/// Ключ по умолчанию, если для проекта/команды иконка ещё не выбрана.
const String kDefaultProjectIconKey = 'folder';

/// Возвращает IconData по ключу из kPickableProjectIcons (или дефолт, если
/// ключ null/неизвестен — например, из старых данных).
IconData iconByKey(String? key) => kPickableProjectIcons[key] ?? kPickableProjectIcons[kDefaultProjectIconKey]!;

/// Диалог выбора иконки — сеткой, тот же стеклянный стиль, что и у
/// showClarifyDatePicker/showMonthYearPicker. Возвращает выбранный ключ
/// (для kPickableProjectIcons) или null при отмене.
Future<String?> showIconPickerDialog({
  required BuildContext context,
  required bool isDark,
  String? current,
}) {
  return showClarifySurface<String>(
    context: context,
    builder: (context) {
      final t = isDark ? ClarifyTokens.dark : ClarifyTokens.light;
      final entries = kPickableProjectIcons.entries.toList();
      return Center(
        child: Material(
          color: Colors.transparent,
          child: ClarifyGlass(
            borderRadius: BorderRadius.circular(ClarifyRadius.lg),
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: 340,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Выберите иконку', style: TextStyle(color: t.text, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 6, crossAxisSpacing: 8, mainAxisSpacing: 8),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      final isSelected = entry.key == current;
                      return Material(
                        color: isSelected ? t.accent : t.surfaceSunken,
                        borderRadius: BorderRadius.circular(ClarifyRadius.sm),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(ClarifyRadius.sm),
                          onTap: () => Navigator.of(context).pop(entry.key),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Icon(entry.value, size: 20, color: isSelected ? t.onAccent : t.text2),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('Отмена', style: TextStyle(color: t.text2))),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
