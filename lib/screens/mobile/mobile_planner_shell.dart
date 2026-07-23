import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/localization.dart';
import '../../core/theme/design_tokens.dart';
import '../../widgets/clarify_glass.dart';
import '../../widgets/clarify_pressable.dart';
import '../../widgets/friends_screen.dart';
import '../../widgets/user_profile_modal.dart';
import '../../widgets/conversations_screen.dart';
import '../../widgets/mobile_quick_add_sheet.dart';
import 'mobile_today_screen.dart';
import 'mobile_tasks_screen.dart';
import 'mobile_teams_screen.dart';
import 'mobile_settings_screen.dart';

enum MobileTab { today, tasks, teams, settings }

/// Мобильная/PWA-оболочка Clarify — отдельно спроектированная навигация
/// (нижний таб-бар + FAB), а не десктопный сайдбар, сжатый в узкий экран.
/// Бизнес-логика (загрузка задач, CRUD, воркспейсы) остаётся в
/// DesktopPlannerScreen — сюда прокидываются только данные и колбэки,
/// как и в остальные вынесенные виджеты приложения.
class MobilePlannerShell extends StatefulWidget {
  final String currentLang;
  final String userInitial;
  final String userFullName;
  final List<Map<String, dynamic>> tasks;
  final List<Map<String, dynamic>> workspaces;
  final Map<int, List<Map<String, dynamic>>> workspaceMembers;
  final String Function(DateTime date) formatDate;
  final Color Function(String? priority) getPriorityColor;
  final Map<String, int> Function(dynamic parentId) getSubtaskStats;
  final bool Function(Map<String, dynamic> task) isOverdue;
  final void Function(Map<String, dynamic> task) onToggleTask;
  final void Function(dynamic taskId) onDeleteTask;
  final void Function(Map<String, dynamic> task) onTaskTap;
  final void Function({DateTime? preselectedDate}) onAddTask;
  final Future<int?> Function(Map<String, dynamic> taskData) createTaskManually;
  final void Function(String dateStr) checkBurnoutWarning;
  final void Function(int workspaceId) onOpenWorkspaceMembers;
  final void Function(int workspaceId) onInviteToWorkspace;
  final void Function(int workspaceId) onShowTeamPulse;
  final void Function(int workspaceId) onLeaveOrDeleteWorkspace;
  final VoidCallback onAddWorkspace;
  final VoidCallback onOpenAccountSettings;
  final Widget Function() buildStatisticsDashboard;
  final bool isDark;
  final VoidCallback toggleTheme;
  final Function(String lang) changeLang;

  const MobilePlannerShell({
    super.key,
    required this.currentLang,
    required this.userInitial,
    required this.userFullName,
    required this.tasks,
    required this.workspaces,
    required this.workspaceMembers,
    required this.formatDate,
    required this.getPriorityColor,
    required this.getSubtaskStats,
    required this.isOverdue,
    required this.onToggleTask,
    required this.onDeleteTask,
    required this.onTaskTap,
    required this.onAddTask,
    required this.createTaskManually,
    required this.checkBurnoutWarning,
    required this.onOpenWorkspaceMembers,
    required this.onInviteToWorkspace,
    required this.onShowTeamPulse,
    required this.onLeaveOrDeleteWorkspace,
    required this.onAddWorkspace,
    required this.onOpenAccountSettings,
    required this.buildStatisticsDashboard,
    required this.isDark,
    required this.toggleTheme,
    required this.changeLang,
  });

  @override
  State<MobilePlannerShell> createState() => _MobilePlannerShellState();
}

class _MobilePlannerShellState extends State<MobilePlannerShell> {
  MobileTab _tab = MobileTab.today;
  // Заданная через мини-календарь «Мой день» дата, на которую нужно открыть
  // «Задачи» — одноразовый «билет», сбрасывается сразу после применения,
  // чтобы повторный визит на вкладку не запирал фильтр на старой дате.
  DateTime? _pendingCalendarDate;

  List<Map<String, dynamic>> get _todayTasks {
    final todayStr = widget.formatDate(DateTime.now());
    final list = widget.tasks.where((t) => t['due_date'] == todayStr && t['parent_id'] == null).toList();
    list.sort((a, b) => (a['due_time'] ?? '23:59').compareTo(b['due_time'] ?? '23:59'));
    return list;
  }

  int get _inboxCount => widget.tasks.where((t) => (t['due_date'] == null || t['due_date'] == '') && t['parent_id'] == null).length;

  Widget _buildTab(MobileTab tab) {
    switch (tab) {
      case MobileTab.today:
        return MobileTodayScreen(
          currentLang: widget.currentLang,
          userInitial: widget.userInitial,
          todayTasks: _todayTasks,
          inboxCount: _inboxCount,
          getPriorityColor: widget.getPriorityColor,
          getSubtaskStats: widget.getSubtaskStats,
          isOverdue: widget.isOverdue,
          onToggle: widget.onToggleTask,
          onDelete: widget.onDeleteTask,
          onTap: widget.onTaskTap,
          onOpenInbox: () => setState(() => _tab = MobileTab.tasks),
          onOpenDate: (date) => setState(() {
            _pendingCalendarDate = date;
            _tab = MobileTab.tasks;
          }),
        );
      case MobileTab.tasks:
        final initialDate = _pendingCalendarDate;
        _pendingCalendarDate = null;
        return MobileTasksScreen(
          currentLang: widget.currentLang,
          tasks: widget.tasks,
          initialDate: initialDate,
          getPriorityColor: widget.getPriorityColor,
          getSubtaskStats: widget.getSubtaskStats,
          isOverdue: widget.isOverdue,
          onToggle: widget.onToggleTask,
          onDelete: widget.onDeleteTask,
          onTap: widget.onTaskTap,
        );
      case MobileTab.teams:
        return MobileTeamsScreen(
          currentLang: widget.currentLang,
          workspaces: widget.workspaces,
          workspaceMembers: widget.workspaceMembers,
          tasks: widget.tasks,
          onAddWorkspace: widget.onAddWorkspace,
          onOpenMembers: widget.onOpenWorkspaceMembers,
          onInvite: widget.onInviteToWorkspace,
          onShowPulse: widget.onShowTeamPulse,
          onLeaveOrDeleteWorkspace: widget.onLeaveOrDeleteWorkspace,
          getPriorityColor: widget.getPriorityColor,
          getSubtaskStats: widget.getSubtaskStats,
          isOverdue: widget.isOverdue,
          onToggleTask: widget.onToggleTask,
          onDeleteTask: widget.onDeleteTask,
          onTaskTap: widget.onTaskTap,
        );
      case MobileTab.settings:
        return MobileSettingsScreen(
          currentLang: widget.currentLang,
          userInitial: widget.userInitial,
          userFullName: widget.userFullName,
          isDark: widget.isDark,
          onOpenAccountSettings: widget.onOpenAccountSettings,
          onOpenStatistics: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => _StatisticsPage(currentLang: widget.currentLang, builder: widget.buildStatisticsDashboard),
          )),
          onOpenFriends: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => _FriendsPage(currentLang: widget.currentLang),
          )),
          onOpenMessages: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => _MessagesPage(currentLang: widget.currentLang),
          )),
          toggleTheme: widget.toggleTheme,
          changeLang: widget.changeLang,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        // FadeThroughTransition вместо мгновенного IndexedStack-переключения —
        // сдержанный переход между вкладками нижней навигации (REDESIGN_V3_PLAN.md
        // §3.6/5.6, эталон движения — Structured).
        child: PageTransitionSwitcher(
          duration: ClarifyMotion.slow,
          transitionBuilder: (child, primaryAnimation, secondaryAnimation) => FadeThroughTransition(
            animation: primaryAnimation,
            secondaryAnimation: secondaryAnimation,
            child: child,
          ),
          child: KeyedSubtree(
            key: ValueKey(_tab),
            child: _buildTab(_tab),
          ),
        ),
      ),
      bottomNavigationBar: _MobileBottomNav(
        current: _tab,
        currentLang: widget.currentLang,
        onSelect: (tab) => setState(() => _tab = tab),
        onAdd: () => showMobileQuickAddSheet(
          context: context,
          currentLang: widget.currentLang,
          createTaskManually: widget.createTaskManually,
          checkBurnoutWarning: widget.checkBurnoutWarning,
          getPriorityColor: widget.getPriorityColor,
          formatDate: widget.formatDate,
        ),
      ),
    );
  }
}

class _MobileBottomNav extends StatelessWidget {
  final MobileTab current;
  final String currentLang;
  final void Function(MobileTab tab) onSelect;
  final VoidCallback onAdd;

  const _MobileBottomNav({required this.current, required this.currentLang, required this.onSelect, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return ClarifyGlass(
      borderRadius: BorderRadius.zero,
      showHighlight: false,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(icon: LucideIcons.sun, label: 'День'.tr(currentLang), active: current == MobileTab.today, onTap: () => onSelect(MobileTab.today)),
            _NavItem(icon: LucideIcons.listChecks, label: 'Задачи'.tr(currentLang), active: current == MobileTab.tasks, onTap: () => onSelect(MobileTab.tasks)),
            _FabItem(onTap: onAdd),
            _NavItem(icon: LucideIcons.usersRound, label: 'Команды'.tr(currentLang), active: current == MobileTab.teams, onTap: () => onSelect(MobileTab.teams)),
            _NavItem(icon: LucideIcons.settings, label: 'Настройки'.tr(currentLang), active: current == MobileTab.settings, onTap: () => onSelect(MobileTab.settings)),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({required this.icon, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = active ? t.accent : t.text3;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ClarifyRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}

class _FabItem extends StatelessWidget {
  final VoidCallback onTap;
  const _FabItem({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ClarifyPressable(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(color: t.accent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: t.accent.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))]),
        child: Icon(LucideIcons.plus, color: t.onAccent, size: 24),
      ),
    );
  }
}

class _FriendsPage extends StatelessWidget {
  final String currentLang;
  const _FriendsPage({required this.currentLang});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        elevation: 0,
        foregroundColor: t.text,
        title: Text('Друзья'.tr(currentLang), style: TextStyle(fontFamily: 'Golos Text', fontWeight: FontWeight.w700)),
      ),
      body: FriendsScreen(
        currentLang: currentLang,
        buildGlassContainer: ({required child, margin, padding, customColor}) => ClarifyGlass(margin: margin, padding: padding, customColor: customColor, child: child),
        onOpenProfile: (userId) => showUserProfileModal(
          context: context,
          userId: userId,
          currentLang: currentLang,
          onOpenConversation: (partnerId, name) => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ConversationScreen(currentLang: currentLang, partnerId: partnerId, partnerName: name),
          )),
        ),
      ),
    );
  }
}

class _MessagesPage extends StatelessWidget {
  final String currentLang;
  const _MessagesPage({required this.currentLang});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        elevation: 0,
        foregroundColor: t.text,
        title: Text('Сообщения'.tr(currentLang), style: TextStyle(fontFamily: 'Golos Text', fontWeight: FontWeight.w700)),
      ),
      body: ConversationsListScreen(
        currentLang: currentLang,
        buildGlassContainer: ({required child, margin, padding, customColor}) => ClarifyGlass(margin: margin, padding: padding, customColor: customColor, child: child),
      ),
    );
  }
}

class _StatisticsPage extends StatelessWidget {
  final String currentLang;
  final Widget Function() builder;
  const _StatisticsPage({required this.currentLang, required this.builder});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        elevation: 0,
        foregroundColor: t.text,
        title: Text('Статистика'.tr(currentLang), style: TextStyle(fontFamily: 'Golos Text', fontWeight: FontWeight.w700)),
      ),
      body: builder(),
    );
  }
}
