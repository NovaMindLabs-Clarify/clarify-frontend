import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/localization.dart';
import '../core/theme/design_tokens.dart';
import 'clarify_press_glow.dart';
import 'icon_picker_dialog.dart';

/// Сайдбар: по умолчанию свёрнут в узкую полосу с иконками, разворачивается
/// по клику (REDESIGN_V3_PLAN.md §5.11). Ширина и раскладка строк
/// анимируются, содержимое (пункты меню/проекты/команды/аккаунт-блок) — одно
/// и то же, просто с подписью или без.
///
/// Изначально переключение было по наведению мыши (MouseRegion.onEnter/
/// onExit) — после нескольких циклов разворота/сворачивания приложение
/// зависало насмерть (не реагировало даже на системную кнопку сворачивания
/// окна), воспроизводимо. Живо отладить зависание невозможно (нет доступа к
/// интерактивным DevTools в этом окружении), а автоматический hover на ~15-20
/// одновременно монтируемых/размонтируемых Tooltip-виджетов при каждом
/// микро-движении мыши — самый вероятный источник гонки. Явный клик меняет
/// состояние ровно по одному чёткому действию пользователя, а не по каждому
/// движению курсора — не гарантия, что причина была именно в этом, но
/// убирает целый класс риска (тот же принцип, что и решение откатить Hero
/// вместо повторных догадок вслепую).
class SidebarMenu extends StatefulWidget {
  final bool isDark;
  final double scale;
  final String currentLang;
  final String selectedMenu;
  final List<String> menuItems;
  final List<dynamic> workspaces;

  // Ключ (см. kPickableProjectIcons в icon_picker_dialog.dart) — не сама
  // IconData, её нельзя хранить произвольно из-за @mustBeConst codePoint.
  final void Function(int workspaceId, String iconKey) onSetWorkspaceIcon;

  final Function(String) onMenuSelected;
  final VoidCallback onAddWorkspace;
  final Function(int, String) onWorkspaceSelected;

  final Widget userAccountBlock;
  final Widget userAccountBlockCollapsed;
  final Widget Function({
    required Widget child,
    BorderRadius? borderRadius,
    EdgeInsetsGeometry? margin,
    Color? customColor,
  })
  buildGlassContainer;

  // Те же соответствия, что и в мобильном нижнем меню (REDESIGN_V3_PLAN.md §3.18/5.17) —
  // не изобретаем новый набор для десктопа.
  static const Map<String, IconData> _menuIcons = {
    'Мой день': LucideIcons.sun,
    'Следующие 7 дней': LucideIcons.calendarDays,
    'Все задачи': LucideIcons.listChecks,
    'Календарь': LucideIcons.calendar,
    'Входящие': LucideIcons.inbox,
    'Проекты': LucideIcons.folderKanban,
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
    required this.onSetWorkspaceIcon,
    required this.onMenuSelected,
    required this.onAddWorkspace,
    required this.onWorkspaceSelected,
    required this.userAccountBlock,
    required this.userAccountBlockCollapsed,
    required this.buildGlassContainer,
  }) : super(key: key);

  @override
  State<SidebarMenu> createState() => _SidebarMenuState();
}

class _SidebarMenuState extends State<SidebarMenu> {
  static const double _collapsedWidth = 76;
  static const double _expandedWidth = 300;

  bool _expanded = false;

  @override
  void didUpdateWidget(SidebarMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Мессенджер — 3-колоночный макет (список чатов + открытый чат) — сам
    // претендует на горизонтальное место, поэтому при входе в него сайдбар
    // сворачивается в icon-полосу по умолчанию. Не блокирует ручной разворот
    // обратно кликом — просто стартовое состояние при переходе.
    if (widget.selectedMenu == 'Сообщения' && oldWidget.selectedMenu != 'Сообщения') {
      _expanded = false;
    }
  }

  Future<void> _pickWorkspaceIcon(int wsId, String? current) async {
    final picked = await showIconPickerDialog(
      context: context,
      isDark: widget.isDark,
      currentLang: widget.currentLang,
      current: current,
    );
    if (picked != null) widget.onSetWorkspaceIcon(wsId, picked);
  }

  // Один и тот же виджет для свёрнутого и развёрнутого состояния — раньше
  // это были две РАЗНЫЕ ветки (Icon-only vs ListTile), переключавшиеся
  // мгновенно по булеву _expanded, пока ширина контейнера ещё анимировалась.
  // На сворачивании это было незаметно (узкий контент и так уже стоял на
  // своём месте, контейнер просто сжимался вокруг него), а на разворачивании
  // подпись целиком появлялась в дереве за один кадр и "выскакивала" из-под
  // ещё не доросшего clip'а. Здесь иконка всегда в одной и той же
  // фиксированной колонке слева, подпись — Expanded с overflow: clip;
  // ширина контейнера при каждом кадре анимации даёт Row ровно столько
  // места, сколько есть в этот момент — подпись естественно "вырастает"
  // вместе с шириной без скачка, одинаково в обе стороны.
  Widget _row({
    required IconData icon,
    required String label,
    required bool selected,
    required Color accentColor,
    required Color textColor,
    required Color textMuted,
    required Color highlightColor,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
    Widget? trailing,
  }) {
    final s = widget.scale;
    final content = ClarifyPressGlow(
      color: accentColor,
      spread: 14 * s,
      child: GestureDetector(
        onLongPress: onLongPress,
        onSecondaryTap: onLongPress,
        child: Material(
          color: selected ? highlightColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12 * s),
          child: InkWell(
            borderRadius: BorderRadius.circular(12 * s),
            onTap: onTap,
            child: SizedBox(
              height: 44 * s,
              child: Row(
                children: [
                  SizedBox(
                    width: (_collapsedWidth - 24) * s,
                    child: Center(
                      child: Icon(
                        icon,
                        size: 20 * s,
                        color: selected ? accentColor : textMuted,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.clip,
                      style: TextStyle(
                        fontSize: 15 * s,
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.w600,
                        color: selected ? accentColor : textColor,
                      ),
                    ),
                  ),
                  if (trailing != null)
                    Padding(
                      padding: EdgeInsets.only(right: 12 * s),
                      child: trailing,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 4 * s),
      child: _expanded ? content : Tooltip(message: label, child: content),
    );
  }

  Widget _sectionLabel(String text, Color textMuted, {Widget? trailing}) {
    if (!_expanded) return SizedBox(height: 16 * widget.scale);
    final s = widget.scale;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24 * s, vertical: 8 * s),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            text.tr(widget.currentLang),
            style: TextStyle(
              fontSize: 12 * s,
              fontWeight: FontWeight.bold,
              color: textMuted,
              letterSpacing: 1.2,
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final textColor = t.text;
    final textMuted = t.text2;
    final highlightColor = t.accentSoft;
    final s = widget.scale;

    return widget.buildGlassContainer(
      borderRadius: const BorderRadius.only(
        topRight: Radius.circular(24),
        bottomRight: Radius.circular(24),
      ),
      margin: EdgeInsets.zero,
      child: AnimatedContainer(
        duration: ClarifyMotion.slow,
        curve: ClarifyMotion.standard,
        width: (_expanded ? _expandedWidth : _collapsedWidth) * s,
        child: ClipRect(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  _expanded ? 28 * s : 0,
                  40 * s,
                  _expanded ? 20 * s : 0,
                  32 * s,
                ),
                child: _expanded
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Clarify",
                            style: TextStyle(
                              fontFamily: 'Unbounded',
                              fontSize: 18 * s,
                              fontWeight: FontWeight.w700,
                              color: t.accent,
                              letterSpacing: -0.01,
                            ),
                          ),
                          ClarifyPressGlow(
                            color: t.accent,
                            spread: 10 * s,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8 * s),
                              onTap: () => setState(() => _expanded = false),
                              child: Padding(
                                padding: EdgeInsets.all(4 * s),
                                child: Icon(
                                  LucideIcons.chevronsLeft,
                                  size: 20 * s,
                                  color: textMuted,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Center(
                        child: ClarifyPressGlow(
                          color: t.accent,
                          spread: 10 * s,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8 * s),
                            onTap: () => setState(() => _expanded = true),
                            child: Padding(
                              padding: EdgeInsets.all(4 * s),
                              child: Icon(
                                LucideIcons.chevronsRight,
                                size: 20 * s,
                                color: textMuted,
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    ...widget.menuItems.map(
                      (item) => _row(
                        icon:
                            SidebarMenu._menuIcons[item] ?? LucideIcons.circle,
                        label: item.tr(widget.currentLang),
                        selected: item == widget.selectedMenu,
                        accentColor: t.accent,
                        textColor: textColor,
                        textMuted: textMuted,
                        highlightColor: highlightColor,
                        onTap: () => widget.onMenuSelected(item),
                      ),
                    ),

                    _sectionLabel(
                      "КОМАНДЫ",
                      textMuted,
                      trailing: InkWell(
                        onTap: widget.onAddWorkspace,
                        child: Icon(
                          LucideIcons.building2,
                          size: 20 * s,
                          color: textMuted,
                        ),
                      ),
                    ),
                    ...widget.workspaces.map((ws) {
                      final wsId = ws['id'] as int;
                      String wsName = ws['name'].toString();
                      String wsMenuKey = 'ws_$wsId';
                      // Метка команды — из назначаемой палитры по id, а не зашитый системный цвет.
                      final wsColor = t.tagPalette[wsId % t.tagPalette.length];
                      final resolvedIcon = ws['icon'] != null
                          ? iconByKey(ws['icon'].toString())
                          : LucideIcons.usersRound;

                      return _row(
                        icon: resolvedIcon,
                        label: wsName,
                        selected: widget.selectedMenu == wsMenuKey,
                        accentColor: wsColor,
                        textColor: textColor,
                        textMuted: textMuted,
                        highlightColor: wsColor.withValues(alpha: 0.15),
                        onTap: () =>
                            widget.onWorkspaceSelected(wsId, wsMenuKey),
                        onLongPress: () =>
                            _pickWorkspaceIcon(wsId, ws['icon']?.toString()),
                      );
                    }),
                  ],
                ),
              ),
              _expanded
                  ? widget.userAccountBlock
                  : widget.userAccountBlockCollapsed,
              SizedBox(height: 24 * s),
            ],
          ),
        ),
      ),
    );
  }
}
