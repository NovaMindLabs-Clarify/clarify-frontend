import 'package:flutter/material.dart';
import '../core/theme/design_tokens.dart';

/// Карточка строки настроек: цветной icon-чип + заголовок + trailing,
/// опционально разворачиваемая под доп. содержимое (замена плоского
/// списка Row+Divider единым визуальным языком окна настроек).
class ClarifySettingsCard extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Widget? expandedChild;
  final bool isExpanded;

  const ClarifySettingsCard({
    super.key,
    required this.icon,
    required this.title,
    this.iconColor,
    this.trailing,
    this.onTap,
    this.expandedChild,
    this.isExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final chipColor = iconColor ?? t.accent;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Container(
      decoration: BoxDecoration(
        color: t.surfaceSunken,
        borderRadius: BorderRadius.circular(ClarifyRadius.md),
        border: Border.all(color: t.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(color: chipColor.withValues(alpha: 0.15), shape: BoxShape.circle),
                    child: Icon(icon, size: 17, color: chipColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(title, style: TextStyle(color: t.text, fontWeight: FontWeight.w600, fontSize: 14.5))),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
          ),
          if (expandedChild != null)
            AnimatedSize(
              duration: reduceMotion ? Duration.zero : ClarifyMotion.base,
              curve: ClarifyMotion.spring,
              alignment: Alignment.topCenter,
              child: isExpanded
                  ? Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 14), child: expandedChild)
                  : const SizedBox(width: double.infinity),
            ),
        ],
      ),
    );
  }
}
