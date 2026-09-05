import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/checklist.dart';
import '../../../core/clarify_date_format.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../widgets/clarify_quick_actions_sheet.dart';
import '../../../widgets/clarify_task_checkbox.dart';

/// Внимание: mobile_task_row.dart и task_cards.dart — два отдельных виджета
/// для одного и того же визуального смысла (десктоп/мобильный ряд задачи),
/// не связаны наследованием. Любой новый бейдж на карточке задачи нужно
/// добавлять в ОБА места — реализация вынесена в общие buildRotBadge/
/// buildRescheduleBadge (clarify_task_checkbox.dart) именно чтобы не
/// дублировать саму логику, но сам факт вызова в каждом виджете дублировать
/// придётся (см. историю бага: бейджи появились только на десктопе, потому
/// что при добавлении забыли про этот файл).

// `overdue`, переданный этому виджету, уже вычислен через isOverdue(task)
// колбэком экрана, который сам возвращает false для выполненных задач (см.
// desktop_planner_screen.dart._isOverdue). Из-за этого `overdue` и `isDone`
// становятся false/true ОДНОВРЕМЕННО в один и тот же ребилд — резервировать
// место под иконку по условию `if (overdue)` не работает, значение уже
// схлопнулось к false к моменту, когда задача отмечена выполненной. Эта
// функция — та же проверка "дедлайн уже прошёл", но БЕЗ раннего return по
// is_completed, специально для резервирования места под иконку.
// Реализация переехала в core/clarify_date_format.dart:taskWasPastDue — одна
// на всё приложение (раньше эта копия и копия в task_cards.dart жили отдельно
// и уже начинали расходиться) и читающая настоящие колонки дат (B4).
bool _wasPastDue(Map<String, dynamic> task) => taskWasPastDue(task);

/// Строка задачи, общая для "Сегодня", "Задачи" и "Команды" на мобильной
/// версии — левая полоса цвета приоритета вместо отдельного кружка-чекбокса
/// с цветной обводкой, как на десктопе (там мышь, здесь палец — крупнее
/// область тапа, меньше мелких деталей).
class MobileTaskRow extends StatelessWidget {
  final Map<String, dynamic> task;
  final Color priorityColor;
  final Map<String, int> subtaskStats;
  final bool overdue;
  final String currentLang;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onTap;
  final void Function(Map<String, dynamic> updates) onQuickUpdateTask;
  final bool showDate;

  const MobileTaskRow({
    super.key,
    required this.task,
    required this.priorityColor,
    required this.subtaskStats,
    required this.overdue,
    required this.currentLang,
    required this.onToggle,
    required this.onDelete,
    required this.onTap,
    required this.onQuickUpdateTask,
    this.showDate = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bool isDone = task['is_completed'] == true;
    final bool hasSubtasks = subtaskStats['total']! > 0;
    final cStats = checklistStats(task['checklist']);
    final bool hasChecklist = cStats['total']! > 0;
    final String? tag = (task['tags'] as String?)?.split(',').first.trim();
    final rotBadge = buildRotBadge(
      task: task,
      isDone: isDone,
      overdue: overdue,
      tokens: t,
      currentLang: currentLang,
    );
    final rescheduleBadge = buildRescheduleBadge(
      task: task,
      isDone: isDone,
      tokens: t,
      currentLang: currentLang,
    );
    // Тап по бейджу гниения открывает быстрые действия вместо простого
    // просмотра — см. showTaskRotQuickActions (пассивный бейдж рискует со
    // временем превратиться в фоновый шум, который перестают замечать).
    final rotBadgeInteractive = rotBadge == null
        ? null
        : Builder(
            builder: (context) => GestureDetector(
              onTap: () => showTaskRotQuickActions(
                context: context,
                isDark: Theme.of(context).brightness == Brightness.dark,
                currentLang: currentLang,
                onDoToday: () => onQuickUpdateTask({
                  'due_date': formatClarifyDate(DateTime.now()),
                }),
                onClearDeadline: () => onQuickUpdateTask({
                  'due_date': null,
                  'due_time': null,
                  'duration_minutes': null,
                }),
                onDelete: onDelete,
              ),
              child: rotBadge,
            ),
          );

    // Зазора между строками больше нет: строки разделяет волосяная линия, а
    // не воздух. Отступ в 8px между карточками был частью «стопки плиток».
    return Padding(
      padding: EdgeInsets.zero,
      child: Material(
        // Прозрачный: заливка теперь красится в AnimatedContainer ниже — у
        // Material.animationDuration нет гарантии анимировать color в этой
        // конфигурации (проверено фактическим прогоном — фон всё равно
        // менялся мгновенно), а AnimatedContainer это делает надёжно
        // (implicit-анимация BoxDecoration — обкатанный Flutter-механизм).
        // Material остаётся только ради InkWell-ряби по тапу.
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(ClarifyRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(ClarifyRadius.md),
          child: AnimatedContainer(
            duration: ClarifyMotion.completion,
            curve: ClarifyMotion.standard,
            decoration: BoxDecoration(
              // Не карточка, а строка (2026-09-04) — тот же язык, что на ПК.
              // Заливка осталась только там, где несёт смысл: просрочка и
              // выполненная. У обычной задачи фона нет: одинаковая подложка у
              // всех строк и превращала список в стопку одинаковых плиток.
              //
              // color применяется, только когда gradient == null (иначе
              // градиент побеждает) — а он и null ровно у выполненной задачи.
              color: isDone ? t.surfaceSunken : null,
              // Приоритет — мягкой заливкой слева вместо полосы в 3px
              // (D2, выбор пользователя 05.09.2026). Полоса на тёмной теме
              // почти не читается, её приходится искать глазами. Значения
              // 1-в-1 с десктопом (TaskCardBuilders._priorityWash): одна и та
              // же задача обязана выглядеть одинаково на ПК и на телефоне.
              gradient: isDone || (priorityColor == t.text3 && !overdue)
                  ? null
                  : LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        (overdue ? t.danger : priorityColor).withValues(
                          alpha: overdue ? 0.30 : 0.22,
                        ),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.45],
                    ),
              border: Border(bottom: BorderSide(color: t.border)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2, right: 10),
                    // ClarifyCheckCircle/ClarifyStrikeText — те же анимированные
                    // примитивы, что и на десктопе (TaskCardBuilders); здесь
                    // раньше стояла голая статичная Icon() без единой анимации,
                    // отметка/снятие выполнения выглядели как мгновенный "скачок"
                    // на всех фронтах сразу (иконка/зачёркивание/цвет).
                    child: ClarifyCheckCircle(
                      size: 22,
                      value: isDone,
                      onTap: onToggle,
                      borderColor: overdue ? t.danger : t.text3,
                      checkedColor: t.success,
                      duration: ClarifyMotion.completion,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClarifyStrikeText(
                          text: task['title'] ?? '',
                          isDone: isDone,
                          style: TextStyle(
                            // Просрочка отличается ещё и кеглем, а не только
                            // цветом (D2) — как в списке на ПК.
                            fontSize: overdue && !isDone ? 16.5 : 15,
                            fontWeight: overdue && !isDone
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: isDone ? t.text3 : t.text,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // Строка 2: просрочка + дата/время + счётчики
                        // подзадач/чек-листа + тег — единая структура с
                        // desktop-версией (task_cards.dart:buildListTaskCard),
                        // согласовано 2026-08-02. Иконка просрочки и дата/
                        // время сгруппированы в свой Row (не голые элементы
                        // плоского Wrap) — иначе выравнивание считается
                        // относительно самого высокого соседа в Wrap
                        // (например бейджа со своим padding), а не друг
                        // относительно друга (живой фидбек: "значки на другой
                        // высоте относительно времени и даты").
                        if (showDate && task['due_date'] != null ||
                            task['due_time'] != null ||
                            hasSubtasks ||
                            hasChecklist ||
                            tag != null ||
                            _wasPastDue(task)) ...[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (showDate && task['due_date'] != null ||
                                  task['due_time'] != null ||
                                  _wasPastDue(task))
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // Слот иконки просрочки закреплён по ширине,
                                    // если дедлайн задачи вообще был в прошлом
                                    // (см. _wasPastDue) — НЕ по `overdue`,
                                    // который сам уже false для выполненных
                                    // задач: иначе слот и не появился бы в тот
                                    // же ребилд, где isDone стал true, и дата
                                    // всё равно "прыгала" бы влево.
                                    if (_wasPastDue(task))
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 4,
                                        ),
                                        child: SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: AnimatedOpacity(
                                            opacity: isDone ? 0 : 1,
                                            duration: ClarifyMotion.completion,
                                            curve: ClarifyMotion.standard,
                                            child: Icon(
                                              LucideIcons.clockAlert,
                                              size: 12,
                                              color: t.danger,
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (showDate && task['due_date'] != null)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 4,
                                        ),
                                        child: AnimatedDefaultTextStyle(
                                          duration: ClarifyMotion.completion,
                                          curve: ClarifyMotion.standard,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: overdue && !isDone
                                                ? t.danger
                                                : t.text3,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          child: Text(task['due_date']),
                                        ),
                                      ),
                                    if (task['due_time'] != null)
                                      AnimatedDefaultTextStyle(
                                        duration: ClarifyMotion.completion,
                                        curve: ClarifyMotion.standard,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: overdue && !isDone
                                              ? t.danger
                                              : t.text3,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        child: Text(task['due_time']),
                                      ),
                                  ],
                                ),
                              // Бейдж подзадач/чек-листа схлопывается, когда сама
                              // задача выполнена — счётчик "N из N" не несёт
                              // смысла после того, как вся задача уже закрыта.
                              // AnimatedSize вместо мгновенного исчезновения —
                              // по аналогии с остальными анимациями отметки.
                              if (hasSubtasks)
                                AnimatedSize(
                                  duration: ClarifyMotion.completion,
                                  curve: ClarifyMotion.standard,
                                  child: isDone
                                      ? const SizedBox.shrink()
                                      : ClarifySubtaskBadge(
                                          done: subtaskStats['done']!,
                                          total: subtaskStats['total']!,
                                          tokens: t,
                                        ),
                                ),
                              if (hasChecklist)
                                AnimatedSize(
                                  duration: ClarifyMotion.completion,
                                  curve: ClarifyMotion.standard,
                                  child: isDone
                                      ? const SizedBox.shrink()
                                      : ClarifySubtaskBadge(
                                          done: cStats['done']!,
                                          total: cStats['total']!,
                                          tokens: t,
                                          icon: LucideIcons.listTodo,
                                        ),
                                ),
                              if (tag != null && tag.isNotEmpty)
                                Text(
                                  '#$tag',
                                  // Тот же приглушённый вид, что на ПК
                                  // (2026-09-04): акцентным цветом метка была
                                  // заметнее самого названия задачи.
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: t.text3,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                        ],
                        // Строка 3: гниение + перенос — отдельно от даты/тега/
                        // чек-листа (не толпятся в одной строке). Гейт на
                        // "would-be" значениях (isDone: false), не на текущих
                        // rotBadge/rescheduleBadge — те специально null, когда
                        // isDone, это и управляет исчезающей анимацией внутри
                        // clarifyAnimatedBadgeSlot; если гасить саму строку по
                        // уже-null значению, слот размонтируется в тот же кадр,
                        // что и isDone, и анимации исчезновения не будет.
                        if (buildRotBadge(
                                  task: task,
                                  isDone: false,
                                  overdue: overdue,
                                  tokens: t,
                                  currentLang: currentLang,
                                ) !=
                                null ||
                            buildRescheduleBadge(
                                  task: task,
                                  isDone: false,
                                  tokens: t,
                                  currentLang: currentLang,
                                ) !=
                                null) ...[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              // clarifyAnimatedBadgeSlot — не только вход, но и
                              // выход анимацией: раньше значки просто исчезали
                              // из Wrap мгновенно, когда становились null.
                              clarifyAnimatedBadgeSlot(rotBadgeInteractive),
                              clarifyAnimatedBadgeSlot(rescheduleBadge),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Крестик остаётся видимым, в отличие от ПК: там быстрые
                  // действия (D2) проявляются по наведению, а на тач-экране
                  // наведения нет — спрятанная кнопка стала бы недоступной.
                  // Заменять её на свайп/долгое нажатие — отдельная работа с
                  // отдельным решением, а не побочный эффект правки внешнего
                  // вида строки.
                  IconButton(
                    icon: Icon(LucideIcons.x, size: 16, color: t.text3),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    onPressed: onDelete,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
