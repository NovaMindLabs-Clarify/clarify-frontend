import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/localization.dart';
import '../../core/theme/design_tokens.dart';
import '../../widgets/clarify_illustrations.dart';
import '../../widgets/clarify_text_field.dart';
import '../../widgets/command_palette.dart' show fuzzyMatches, fuzzyScore;
import 'widgets/mobile_task_row.dart';

/// Поиск задач на мобильном — тот же нечёткий (subsequence) движок, что и в
/// десктопной командной палитре (fuzzyMatches/fuzzyScore, command_palette.dart),
/// но отдельный полноэкранный виджет, а не портирование _CommandPalette:
/// у той фиксированная десктопная ширина (620) и раскладка под клавиатурные
/// стрелки/Ctrl+K, которых на мобильном просто нет — там точка входа - тап по
/// иконке в шапке "Задачи".
class MobileSearchScreen extends StatefulWidget {
  final String currentLang;
  final List<Map<String, dynamic>> tasks;
  final Color Function(String? priority) getPriorityColor;
  final Map<String, int> Function(dynamic parentId) getSubtaskStats;
  final bool Function(Map<String, dynamic> task) isOverdue;
  final void Function(Map<String, dynamic> task) onToggle;
  final void Function(dynamic taskId) onDelete;
  final void Function(Map<String, dynamic> task) onTap;
  final void Function(dynamic taskId, Map<String, dynamic> updates) onQuickUpdateTask;

  const MobileSearchScreen({
    super.key,
    required this.currentLang,
    required this.tasks,
    required this.getPriorityColor,
    required this.getSubtaskStats,
    required this.isOverdue,
    required this.onToggle,
    required this.onDelete,
    required this.onTap,
    required this.onQuickUpdateTask,
  });

  @override
  State<MobileSearchScreen> createState() => _MobileSearchScreenState();
}

class _MobileSearchScreenState extends State<MobileSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _handleChanged(String value) {
    _debounce?.cancel();
    // Тот же дебаунс (120мс), что и в десктопной палитре — без него
    // фильтрация+сортировка всего списка задач на каждую нажатую клавишу
    // ощутимо лагает на большом списке.
    _debounce = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      setState(() => _query = value);
    });
  }

  List<Map<String, dynamic>> get _results {
    if (_query.isEmpty) return const [];
    final matches = widget.tasks.where((task) {
      final title = task['title']?.toString() ?? '';
      final note = task['note']?.toString() ?? '';
      return fuzzyMatches(title, _query) || fuzzyMatches(note, _query);
    }).toList()
      ..sort((a, b) => fuzzyScore((a['title'] ?? '').toString(), _query)
          .compareTo(fuzzyScore((b['title'] ?? '').toString(), _query)));
    return matches;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final results = _results;

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(LucideIcons.arrowLeft, color: t.text),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: ClarifyTextField(
                      controller: _controller,
                      autofocus: true,
                      style: TextStyle(color: t.text, fontSize: 16),
                      hintText: 'Поиск задач...'.tr(widget.currentLang),
                      prefixIcon: Icon(LucideIcons.search, color: t.text3, size: 20),
                      onChanged: _handleChanged,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _query.isEmpty
                  ? _hint(t, 'Начните вводить, чтобы найти задачу'.tr(widget.currentLang), LucideIcons.search)
                  : results.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ClarifyIllustration(type: ClarifyIllustrationType.checklistFold, size: 72),
                                const SizedBox(height: 16),
                                Text(
                                  'Ничего не найдено'.tr(widget.currentLang),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: t.text2),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          itemCount: results.length,
                          itemBuilder: (context, index) {
                            final task = results[index];
                            return MobileTaskRow(
                              key: ValueKey(task['id'].toString()),
                              task: task,
                              priorityColor: widget.getPriorityColor(task['priority']),
                              subtaskStats: widget.getSubtaskStats(task['id']),
                              overdue: widget.isOverdue(task),
                              currentLang: widget.currentLang,
                              showDate: true,
                              onToggle: () => widget.onToggle(task),
                              onDelete: () => widget.onDelete(task['id']),
                              onTap: () {
                                Navigator.of(context).pop();
                                widget.onTap(task);
                              },
                              onQuickUpdateTask: (updates) => widget.onQuickUpdateTask(task['id'], updates),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hint(ClarifyTokens t, String text, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: t.text3),
            const SizedBox(height: 16),
            Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: t.text3)),
          ],
        ),
      ),
    );
  }
}
