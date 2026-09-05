import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/localization.dart';
import '../core/theme/design_tokens.dart';
import 'clarify_press_glow.dart';
import 'icon_picker_dialog.dart';

/// Навигационная оболочка v4 (REDESIGN_V4_PLAN.md §6.2): постоянная узкая
/// icon-rail, без состояния "свёрнут/развёрнут" — ширина фиксирована, вопрос
/// плавности разворота/сворачивания снят полностью. Список команд, которому
/// раньше не хватало места в свёрнутом виде, вынесен в контекстную вторую
/// колонку, раскрывающуюся рядом с rail по клику на пункт "Команды" — тот же
/// паттерн предполагается планом для будущего списка чатов/друзей
/// 3-колоночного мессенджера, здесь подключён только для команд.
///
/// Активное состояние пункта rail — не смена цвета заливки, а смена формы и
/// масштаба (круг → скруглённый квадрат, см. `_railIcon`), на кривой
/// `ClarifyMotion.spring` (§6.2/§6.7) — тот же принцип, что и в референсе
/// Icon Flip Button Bar (gskinner Flutter Vignettes), без копирования их
/// Canvas-реализации.
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

  // Поиск раньше был доступен только по Ctrl+F — ничем не отличался от
  // невидимой функции для тех, кто не знает про горячую клавишу (на
  // мобильном есть заметная иконка в шапке "Задач"). Кнопка на рейле
  // добавлена по прямому запросу — 2026-08-01.
  final VoidCallback onSearchTap;

  final Widget userAccountBlockCollapsed;

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
    'Корзина': LucideIcons.trash2,
  };

  const SidebarMenu({
    super.key,
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
    required this.onSearchTap,
    required this.userAccountBlockCollapsed,
  });

  @override
  State<SidebarMenu> createState() => _SidebarMenuState();
}

class _SidebarMenuState extends State<SidebarMenu> {
  static const double _railWidth = 76;
  static const double _teamsPanelWidth = 240;

  /// Скругление правого края оболочки сайдбара. Принадлежит той колонке,
  /// которая сейчас крайняя справа: закрыта панель команд — рейлу, открыта —
  /// панели. См. комментарий в [build].
  static const double _shellRadius = 24;

  late bool _teamsPanelOpen;

  @override
  void initState() {
    super.initState();
    _teamsPanelOpen = widget.selectedMenu.startsWith('ws_');
  }

  @override
  void didUpdateWidget(SidebarMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Мессенджер — свой 3-колоночный макет, сам претендует на горизонтальное
    // место, поэтому при входе в него панель команд закрывается. Не блокирует
    // ручное повторное открытие — просто стартовое состояние при переходе.
    if (widget.selectedMenu == 'Сообщения' && oldWidget.selectedMenu != 'Сообщения') {
      _teamsPanelOpen = false;
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

  Widget _railIcon({
    required IconData icon,
    required String label,
    required bool selected,
    required Color accentColor,
    required Color textMuted,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    final s = widget.scale;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 3 * s),
      child: Tooltip(
        message: label,
        child: ClarifyPressGlow(
          color: accentColor,
          spread: 14 * s,
          child: GestureDetector(
            onLongPress: onLongPress,
            onSecondaryTap: onLongPress,
            child: InkWell(
              borderRadius: BorderRadius.circular(16 * s),
              onTap: onTap,
              child: SizedBox(
                width: _railWidth * s,
                height: 48 * s,
                child: Center(
                  child: AnimatedContainer(
                    duration: ClarifyMotion.slow,
                    curve: ClarifyMotion.spring,
                    width: (selected ? 44 : 36) * s,
                    height: (selected ? 40 : 36) * s,
                    decoration: BoxDecoration(
                      color: selected ? accentColor.withValues(alpha: 0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular((selected ? 14 : 18) * s),
                    ),
                    child: Icon(icon, size: 20 * s, color: selected ? accentColor : textMuted),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _teamRow(ClarifyTokens t, dynamic ws) {
    final s = widget.scale;
    final wsId = ws['id'] as int;
    final wsName = ws['name'].toString();
    final wsMenuKey = 'ws_$wsId';
    // Метка команды — из назначаемой палитры по id, а не зашитый системный цвет.
    final wsColor = t.tagPalette[wsId % t.tagPalette.length];
    final resolvedIcon = ws['icon'] != null ? iconByKey(ws['icon'].toString()) : LucideIcons.usersRound;
    final selected = widget.selectedMenu == wsMenuKey;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 3 * s),
      child: ClarifyPressGlow(
        color: wsColor,
        spread: 14 * s,
        child: GestureDetector(
          onLongPress: () => _pickWorkspaceIcon(wsId, ws['icon']?.toString()),
          onSecondaryTap: () => _pickWorkspaceIcon(wsId, ws['icon']?.toString()),
          child: Material(
            color: selected ? wsColor.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(12 * s),
            child: InkWell(
              borderRadius: BorderRadius.circular(12 * s),
              onTap: () => widget.onWorkspaceSelected(wsId, wsMenuKey),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 10 * s),
                child: Row(
                  children: [
                    Icon(resolvedIcon, size: 18 * s, color: selected ? wsColor : t.text2),
                    SizedBox(width: 10 * s),
                    Expanded(
                      child: Text(
                        wsName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14 * s, fontWeight: selected ? FontWeight.bold : FontWeight.w600, color: selected ? wsColor : t.text),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _teamsPanel(ClarifyTokens t) {
    final s = widget.scale;
    final width = (_teamsPanelOpen ? _teamsPanelWidth : 0) * s;
    return AnimatedContainer(
      duration: ClarifyMotion.slow,
      curve: ClarifyMotion.spring,
      width: width,
      child: ClipRect(
        child: OverflowBox(
          minWidth: _teamsPanelWidth * s,
          maxWidth: _teamsPanelWidth * s,
          alignment: Alignment.centerLeft,
          child: Container(
            decoration: BoxDecoration(
              color: t.surface2,
              // Панель — крайняя правая колонка сайдбара, пока открыта, поэтому
              // правое скругление оболочки на это время её (фидбек 2026-09-03:
              // прямые углы панели встык к скруглённому рейлу выглядели как два
              // случайно составленных блока). Рейл своё скругление в этот
              // момент отдаёт — см. build.
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(_shellRadius),
                bottomRight: Radius.circular(_shellRadius),
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: widget.isDark ? 0.3 : 0.08), blurRadius: 16, offset: const Offset(4, 0)),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(20 * s, 40 * s, 12 * s, 12 * s),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "КОМАНДЫ".tr(widget.currentLang),
                        style: TextStyle(fontSize: 12 * s, fontWeight: FontWeight.bold, color: t.text2, letterSpacing: 1.2),
                      ),
                      InkWell(
                        borderRadius: BorderRadius.circular(8 * s),
                        onTap: widget.onAddWorkspace,
                        child: Padding(
                          padding: EdgeInsets.all(6 * s),
                          child: Icon(LucideIcons.plus, size: 18 * s, color: t.text2),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: widget.workspaces.map((ws) => _teamRow(t, ws)).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final textMuted = t.text2;
    final s = widget.scale;
    final teamsActive = widget.selectedMenu.startsWith('ws_') || _teamsPanelOpen;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Пока панель команд открыта, правый край оболочки — её край, поэтому
        // рейл своё скругление на это время убирает: у пары всегда ровно один
        // скруглённый правый силуэт, а не два встык. Радиус анимируется тем же
        // темпом, что и выезд панели (мгновенный щелчок угла на фоне плавно
        // едущей панели читался бы как рассинхрон), но кривой standard, не
        // spring: у spring есть перелёт, а отрицательный радиус — assert в
        // Radius.circular.
        TweenAnimationBuilder<double>(
          tween: Tween<double>(end: _teamsPanelOpen ? 0 : _shellRadius),
          duration: ClarifyMotion.slow,
          curve: ClarifyMotion.standard,
          builder: (context, radius, child) {
            final shellShape = BorderRadius.only(
              topRight: Radius.circular(radius),
              bottomRight: Radius.circular(radius),
            );
            return Container(
              width: _railWidth * s,
              decoration: BoxDecoration(color: t.surface, borderRadius: shellShape),
              child: ClipRRect(borderRadius: shellShape, child: child),
            );
          },
          child: SizedBox(
            width: _railWidth * s,
            child: Column(
              children: [
                // Аватар профиля вместо буквы "C" вверху рейла (фидбек
                // пользователя 2026-08-01) — сама кнопка настроек, ранее
                // стоявшая тут внизу, переехала в общий список ниже как
                // обычная вкладка (см. "Настройки" после "Команд").
                widget.userAccountBlockCollapsed,
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _railIcon(
                        icon: LucideIcons.search,
                        label: "Поиск".tr(widget.currentLang),
                        selected: false,
                        accentColor: t.accent,
                        textMuted: textMuted,
                        onTap: widget.onSearchTap,
                      ),
                      ...widget.menuItems.map(
                        (item) => _railIcon(
                          icon: SidebarMenu._menuIcons[item] ?? LucideIcons.circle,
                          // 'Сообщения' — внутренний ключ маршрутизации (main_content_area.dart
                          // и т.д.), не трогаем; на экране показываем "Мессенджер" — тот же
                          // подпись, что и на мобильной версии (mobile_planner_shell.dart).
                          label: (item == 'Сообщения' ? 'Мессенджер' : item).tr(widget.currentLang),
                          selected: item == widget.selectedMenu,
                          accentColor: t.accent,
                          textMuted: textMuted,
                          onTap: () {
                            setState(() => _teamsPanelOpen = false);
                            widget.onMenuSelected(item);
                          },
                        ),
                      ),
                      _railIcon(
                        icon: LucideIcons.building2,
                        label: "Команды".tr(widget.currentLang),
                        selected: teamsActive,
                        accentColor: t.accent,
                        textMuted: textMuted,
                        onTap: () => setState(() => _teamsPanelOpen = !_teamsPanelOpen),
                      ),
                    ],
                  ),
                ),
                // Полноценная вкладка "Настройки" (та же карточка настроек,
                // что и в диалоге, только встроена как основной контент) —
                // на месте, где раньше был аватар профиля.
                _railIcon(
                  icon: LucideIcons.settings,
                  label: "Настройки".tr(widget.currentLang),
                  selected: widget.selectedMenu == 'Настройки',
                  accentColor: t.accent,
                  textMuted: textMuted,
                  onTap: () {
                    setState(() => _teamsPanelOpen = false);
                    widget.onMenuSelected('Настройки');
                  },
                ),
                SizedBox(height: 24 * s),
              ],
            ),
          ),
        ),
        _teamsPanel(t),
      ],
    );
  }
}
