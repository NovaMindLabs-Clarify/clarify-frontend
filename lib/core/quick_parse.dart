/// Разбор задачи из одной строки: «завтра в 15 позвонить Ивану #работа !1».
///
/// C1 из docs/AUDIT_2026-09-04.md. Разбор ЛОКАЛЬНЫЙ, без обращения к ИИ, и это
/// не экономия, а требование: /tasks/parse ходит в бесплатные модели
/// OpenRouter и отвечает секунды (в ai_parser.py таймаут 15 секунд на попытку,
/// плюс запасные модели). Быстрый ввод, который думает три секунды, — это уже
/// не быстрый ввод. ИИ остаётся там, где он к месту: в чате ассистента, где
/// ожидание естественно и где он умеет то, чего правила не умеют.
///
/// Разбор СОЗНАТЕЛЬНО консервативен. Ложное срабатывание здесь дороже
/// пропуска: не распознали дату — человек допишет руками, а вот съеденное из
/// названия слово («купить хлеб в 15 магазине») он заметит не сразу. Поэтому
/// время без двоеточия распознаётся, только если рядом стоит явный маркер
/// («в 15:00», «в 15 часов», «в 9 утра»), а голое число временем не считается.
library;

/// Что удалось распознать. [start]/[end] — границы куска в исходной строке,
/// нужны интерфейсу, чтобы подсветить распознанное прямо в поле ввода.
class QuickParseToken {
  final QuickParseKind kind;
  final String text;
  final int start;
  final int end;

  const QuickParseToken({
    required this.kind,
    required this.text,
    required this.start,
    required this.end,
  });
}

enum QuickParseKind { date, time, tag, priority }

class QuickParseResult {
  /// Название задачи — исходная строка без распознанных кусков.
  final String title;
  final DateTime? date;

  /// 'ЧЧ:ММ' — в том же виде, в каком время хранится у задачи.
  final String? time;
  final String? tag;

  /// 'red' | 'orange' | 'blue' | 'gray' — исторические имена в БД.
  final String? priority;

  final List<QuickParseToken> tokens;

  const QuickParseResult({
    required this.title,
    this.date,
    this.time,
    this.tag,
    this.priority,
    this.tokens = const [],
  });

  bool get hasAnything => date != null || time != null || tag != null || priority != null;
}

const Map<String, int> _weekdays = {
  'понедельник': DateTime.monday,
  'вторник': DateTime.tuesday,
  'среда': DateTime.wednesday,
  'среду': DateTime.wednesday,
  'четверг': DateTime.thursday,
  'пятница': DateTime.friday,
  'пятницу': DateTime.friday,
  'суббота': DateTime.saturday,
  'субботу': DateTime.saturday,
  'воскресенье': DateTime.sunday,
};

const Map<String, int> _months = {
  'января': 1, 'февраля': 2, 'марта': 3, 'апреля': 4, 'мая': 5, 'июня': 6,
  'июля': 7, 'августа': 8, 'сентября': 9, 'октября': 10, 'ноября': 11, 'декабря': 12,
};

/// !1..!4 — те же четыре уровня, что и в интерфейсе задачи.
const Map<String, String> _priorityByDigit = {
  '1': 'red',
  '2': 'orange',
  '3': 'blue',
  '4': 'gray',
};

QuickParseResult parseQuickTask(String input, {DateTime? now}) {
  final DateTime today = _dayOnly(now ?? DateTime.now());
  final List<QuickParseToken> tokens = [];

  DateTime? date;
  String? time;
  String? tag;
  String? priority;

  void take(QuickParseKind kind, RegExpMatch m) {
    tokens.add(QuickParseToken(
      kind: kind,
      text: m.group(0)!,
      start: m.start,
      end: m.end,
    ));
  }

  // --- приоритет: !1..!4 ---
  final priorityMatch = RegExp(r'(?<=^|\s)!([1-4])(?=\s|$)').firstMatch(input);
  if (priorityMatch != null) {
    priority = _priorityByDigit[priorityMatch.group(1)!];
    take(QuickParseKind.priority, priorityMatch);
  }

  // --- тег: #слово ---
  final tagMatch = RegExp(r'(?<=^|\s)#([^\s#]+)').firstMatch(input);
  if (tagMatch != null) {
    tag = tagMatch.group(1);
    take(QuickParseKind.tag, tagMatch);
  }

  // --- время ---
  // Только с явным маркером: двоеточие, «часов», «утра/дня/вечера/ночи».
  // Голое «в 15» временем НЕ считается — слишком легко съесть кусок названия.
  final timeMatch = RegExp(
    r'(?<=^|\s)(?:в\s+)?(\d{1,2})[:.](\d{2})(?=\s|$)'
    r'|(?<=^|\s)в\s+(\d{1,2})\s*(?:час(?:ов|а)?)(?=\s|$)'
    r'|(?<=^|\s)в\s+(\d{1,2})\s*(утра|дня|вечера|ночи)(?=\s|$)',
    caseSensitive: false,
  ).firstMatch(input);
  if (timeMatch != null) {
    int? hour;
    int minute = 0;
    if (timeMatch.group(1) != null) {
      hour = int.tryParse(timeMatch.group(1)!);
      minute = int.tryParse(timeMatch.group(2)!) ?? 0;
    } else if (timeMatch.group(3) != null) {
      hour = int.tryParse(timeMatch.group(3)!);
    } else if (timeMatch.group(4) != null) {
      hour = int.tryParse(timeMatch.group(4)!);
      final part = timeMatch.group(5)!.toLowerCase();
      if (hour != null) {
        // «в 7 вечера» → 19:00, «в 12 ночи» → 00:00.
        if ((part == 'вечера' || part == 'дня') && hour < 12) hour += 12;
        if (part == 'ночи' && hour == 12) hour = 0;
        if (part == 'утра' && hour == 12) hour = 0;
      }
    }
    if (hour != null && hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
      time = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
      take(QuickParseKind.time, timeMatch);
    }
  }

  // --- дата ---
  date = _matchRelativeDate(input, today, take) ??
      _matchWeekday(input, today, take) ??
      _matchInDays(input, today, take) ??
      _matchNumericDate(input, today, take) ??
      _matchMonthName(input, today, take);

  // --- название: вырезаем распознанное ---
  final title = _stripTokens(input, tokens);

  return QuickParseResult(
    title: title,
    date: date,
    time: time,
    tag: tag,
    priority: priority,
    tokens: tokens,
  );
}

DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime? _matchRelativeDate(
  String input,
  DateTime today,
  void Function(QuickParseKind, RegExpMatch) take,
) {
  final m = RegExp(r'(?<=^|\s)(сегодня|завтра|послезавтра)(?=\s|$)', caseSensitive: false)
      .firstMatch(input);
  if (m == null) return null;
  take(QuickParseKind.date, m);
  switch (m.group(1)!.toLowerCase()) {
    case 'сегодня':
      return today;
    case 'завтра':
      return today.add(const Duration(days: 1));
    default:
      return today.add(const Duration(days: 2));
  }
}

DateTime? _matchWeekday(
  String input,
  DateTime today,
  void Function(QuickParseKind, RegExpMatch) take,
) {
  final m = RegExp(
    r'(?<=^|\s)(?:в|во)\s+(понедельник|вторник|среду|среда|четверг|пятницу|пятница|субботу|суббота|воскресенье)(?=\s|$)',
    caseSensitive: false,
  ).firstMatch(input);
  if (m == null) return null;
  final target = _weekdays[m.group(1)!.toLowerCase()];
  if (target == null) return null;
  take(QuickParseKind.date, m);
  // Ближайший такой день недели, не считая сегодняшнего: «во вторник»,
  // сказанное во вторник, естественнее понимать как следующий вторник.
  int delta = (target - today.weekday) % 7;
  if (delta <= 0) delta += 7;
  return today.add(Duration(days: delta));
}

DateTime? _matchInDays(
  String input,
  DateTime today,
  void Function(QuickParseKind, RegExpMatch) take,
) {
  final m = RegExp(
    r'(?<=^|\s)через\s+(\d{1,3})\s*(день|дня|дней|недел[юия]|недель)(?=\s|$)',
    caseSensitive: false,
  ).firstMatch(input);
  if (m == null) return null;
  final n = int.tryParse(m.group(1)!);
  if (n == null) return null;
  take(QuickParseKind.date, m);
  final unit = m.group(2)!.toLowerCase();
  final days = unit.startsWith('недел') ? n * 7 : n;
  return today.add(Duration(days: days));
}

DateTime? _matchNumericDate(
  String input,
  DateTime today,
  void Function(QuickParseKind, RegExpMatch) take,
) {
  final m = RegExp(r'(?<=^|\s)(\d{1,2})\.(\d{1,2})(?:\.(\d{2,4}))?(?=\s|$)')
      .firstMatch(input);
  if (m == null) return null;
  final day = int.tryParse(m.group(1)!);
  final month = int.tryParse(m.group(2)!);
  if (day == null || month == null || month < 1 || month > 12 || day < 1 || day > 31) {
    return null;
  }
  int year = today.year;
  final rawYear = m.group(3);
  if (rawYear != null) {
    final parsed = int.tryParse(rawYear);
    if (parsed == null) return null;
    year = rawYear.length == 2 ? 2000 + parsed : parsed;
  }
  final candidate = DateTime(year, month, day);
  if (candidate.month != month || candidate.day != day) return null; // 31.02 и подобное
  take(QuickParseKind.date, m);
  // Год не указан и дата уже прошла — значит имеется в виду следующий год.
  if (rawYear == null && candidate.isBefore(today)) {
    return DateTime(year + 1, month, day);
  }
  return candidate;
}

DateTime? _matchMonthName(
  String input,
  DateTime today,
  void Function(QuickParseKind, RegExpMatch) take,
) {
  final m = RegExp(
    r'(?<=^|\s)(\d{1,2})\s+(января|февраля|марта|апреля|мая|июня|июля|августа|сентября|октября|ноября|декабря)(?=\s|$)',
    caseSensitive: false,
  ).firstMatch(input);
  if (m == null) return null;
  final day = int.tryParse(m.group(1)!);
  final month = _months[m.group(2)!.toLowerCase()];
  if (day == null || month == null) return null;
  final candidate = DateTime(today.year, month, day);
  if (candidate.month != month || candidate.day != day) return null;
  take(QuickParseKind.date, m);
  if (candidate.isBefore(today)) return DateTime(today.year + 1, month, day);
  return candidate;
}

/// Вырезает распознанные куски и приводит пробелы в порядок.
String _stripTokens(String input, List<QuickParseToken> tokens) {
  if (tokens.isEmpty) return input.trim();
  final sorted = [...tokens]..sort((a, b) => b.start.compareTo(a.start));
  var result = input;
  for (final token in sorted) {
    result = result.replaceRange(token.start, token.end, ' ');
  }
  return result.replaceAll(RegExp(r'\s+'), ' ').trim();
}
