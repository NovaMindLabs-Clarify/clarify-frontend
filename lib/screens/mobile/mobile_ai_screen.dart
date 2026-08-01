import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/app_settings.dart';
import '../../core/localization.dart';
import '../../core/theme/design_tokens.dart';
import '../../widgets/clarify_illustrations.dart';
import '../../widgets/voice_record_button.dart';
import '../desktop_planner_screen.dart' show AiParseHttpException;

/// Полноэкранная мобильная версия AI-ассистента (desktop-аналог —
/// `widgets/ai_chat_panel.dart`, встроенный в боковую панель, которой на
/// мобильном нет). Логика общения с ассистентом (`onParseText`) приходит из
/// DesktopPlannerScreen — тот же `/tasks/parse` эндпоинт и OpenRouter, что и
/// на десктопе, просто с отдельным полноэкранным UI и собственным
/// состоянием чата вместо общего с десктопной панелью. Ассистент теперь не
/// только создаёт задачи, но и видит текущие (может переносить/отмечать
/// выполненными) и отвечает на вопросы — onParseText возвращает его
/// естественно-языковой ответ, а не счётчик созданных задач.
class MobileAiScreen extends StatefulWidget {
  final String currentLang;
  final Future<String> Function(String text, List<Map<String, String>> history) onParseText;
  final Future<String> Function(Uint8List audioBytes, String filename, String contentType) onTranscribeVoice;

  const MobileAiScreen({super.key, required this.currentLang, required this.onParseText, required this.onTranscribeVoice});

  @override
  State<MobileAiScreen> createState() => _MobileAiScreenState();
}

class _MobileAiScreenState extends State<MobileAiScreen> {
  final List<Map<String, String>> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;
  late final bool _showOnboardingTip = !AppSettings.aiOnboardingSeen;

  @override
  void initState() {
    super.initState();
    if (_showOnboardingTip) AppSettings.aiOnboardingSeen = true;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  // overrideText/displayText — для голосовых сообщений (_sendVoiceMessage):
  // ассистенту отправляется чистый расшифрованный текст, а в чате при этом
  // показывается "🎤 <текст>", как на десктопе (_sendTaskToAI).
  Future<void> _send({String? overrideText, String? displayText}) async {
    final text = (overrideText ?? _controller.text).trim();
    if (text.isEmpty || _isTyping) return;
    // Снимок истории ДО добавления текущего сообщения, с тем же лимитом, что
    // и на десктопе (_sendTaskToAI) — иначе промпт разрастался бы с каждым
    // новым сообщением в затянувшемся чате.
    const historyLimit = 8;
    final history = _messages.length > historyLimit ? _messages.sublist(_messages.length - historyLimit) : List<Map<String, String>>.from(_messages);
    setState(() {
      _messages.add({'role': 'user', 'text': (displayText ?? text).trim()});
      _isTyping = true;
    });
    if (overrideText == null) _controller.clear();
    _scrollToBottom();
    try {
      final reply = await widget.onParseText(text, history);
      if (!mounted) return;
      setState(() {
        _messages.add({'role': 'ai', 'text': reply});
        _isTyping = false;
      });
    } on AiParseHttpException catch (e) {
      // Раньше этот случай (сервер честно ответил, но не 200 — например 401
      // при истёкшей сессии или 500) ловился тем же общим catch (_), что и
      // сетевой обрыв, и показывал одно и то же бесполезное "Ошибка связи
      // с ИИ." без кода ответа — как на десктопе (_sendTaskToAI), так и
      // здесь. Разделяем на два случая, как на десктопе.
      if (!mounted) return;
      final body = e.body.substring(0, e.body.length > 120 ? 120 : e.body.length);
      setState(() {
        _messages.add({'role': 'ai', 'text': 'Ошибка: сервер вернул ${e.statusCode} ($body)'});
        _isTyping = false;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      // Сетевой уровень (таймаут/CORS/обрыв связи/невалидный JSON) — раньше
      // исключение просто отбрасывалось (catch (_)). Короткий e.toString() в
      // самом сообщении делает следующий скриншот сразу диагностируемым, без
      // повторного гадания.
      final detail = e.toString();
      setState(() {
        _messages.add({
          'role': 'ai',
          'text': '${'Ошибка связи с ИИ.'.tr(widget.currentLang)} (${detail.substring(0, detail.length > 120 ? 120 : detail.length)})',
        });
        _isTyping = false;
      });
    }
    _scrollToBottom();
  }

  // Голосовое сообщение — по аналогии с Telegram-ботом этого же приложения:
  // запись загружается на /ai/transcribe-voice (widget.onTranscribeVoice,
  // та же Groq Whisper обёртка, что и у бота), расшифрованный текст
  // добавляется в чат с префиксом "🎤" и уходит ассистенту как обычное
  // сообщение — вместо прежнего живого расшифровывания speech_to_text прямо
  // в текстовое поле по ходу речи.
  Future<void> _sendVoiceMessage(Uint8List bytes, String filename, String contentType) async {
    if (_isTyping) return;
    setState(() => _isTyping = true);
    String transcribedText;
    try {
      transcribedText = await widget.onTranscribeVoice(bytes, filename, contentType);
    } on AiParseHttpException catch (e) {
      if (!mounted) return;
      final body = e.body.substring(0, e.body.length > 120 ? 120 : e.body.length);
      setState(() {
        _messages.add({'role': 'ai', 'text': 'Ошибка: сервер вернул ${e.statusCode} ($body)'});
        _isTyping = false;
      });
      _scrollToBottom();
      return;
    } on Exception catch (e) {
      if (!mounted) return;
      final detail = e.toString();
      setState(() {
        _messages.add({
          'role': 'ai',
          'text': '${'Ошибка расшифровки голосового.'.tr(widget.currentLang)} (${detail.substring(0, detail.length > 120 ? 120 : detail.length)})',
        });
        _isTyping = false;
      });
      _scrollToBottom();
      return;
    }
    if (transcribedText.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _messages.add({'role': 'ai', 'text': 'Не удалось распознать речь.'.tr(widget.currentLang)});
        _isTyping = false;
      });
      _scrollToBottom();
      return;
    }
    setState(() => _isTyping = false);
    await _send(overrideText: transcribedText, displayText: '🎤 $transcribedText');
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        elevation: 0,
        foregroundColor: t.text,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.sparkles, color: t.accent, size: 20),
            const SizedBox(width: 8),
            Text('AI Ассистент'.tr(widget.currentLang), style: const TextStyle(fontFamily: 'Golos Text', fontWeight: FontWeight.w700)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: _showOnboardingTip
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const ClarifyIllustration(type: ClarifyIllustrationType.aiSpark, size: 88),
                                const SizedBox(height: 20),
                                Text(
                                  'Опиши задачи текстом или голосом — ИИ сам расставит даты, время и приоритеты.'.tr(widget.currentLang),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: t.text3, fontSize: 15),
                                ),
                              ],
                            )
                          : Text(
                              'Опиши задачу...'.tr(widget.currentLang),
                              textAlign: TextAlign.center,
                              style: TextStyle(color: t.text3, fontSize: 14),
                            ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(20),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isAi = msg['role'] == 'ai';
                      return Align(
                        alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                          decoration: BoxDecoration(
                            color: isAi ? t.surface2 : t.accent,
                            borderRadius: BorderRadius.circular(16).copyWith(
                              bottomLeft: isAi ? const Radius.circular(0) : const Radius.circular(16),
                              bottomRight: !isAi ? const Radius.circular(0) : const Radius.circular(16),
                            ),
                            border: isAi ? Border.all(color: t.border) : null,
                          ),
                          child: Text(msg['text']!, style: TextStyle(color: isAi ? t.text : t.onAccent, fontSize: 15)),
                        ),
                      );
                    },
                  ),
          ),
          if (_isTyping)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Печатает...'.tr(widget.currentLang), style: TextStyle(color: t.text3, fontSize: 14, fontStyle: FontStyle.italic)),
              ),
            ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: t.border))),
              child: TextField(
                controller: _controller,
                maxLines: 5,
                minLines: 1,
                style: TextStyle(color: t.text, fontSize: 15),
                keyboardType: TextInputType.multiline,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Вставь ТЗ или нажми микрофон...'.tr(widget.currentLang),
                  hintStyle: TextStyle(color: t.text3, fontSize: 14),
                  filled: true,
                  fillColor: t.surface2,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: VoiceRecordButton(currentLang: widget.currentLang, onRecorded: _sendVoiceMessage),
                      ),
                      IconButton(icon: Icon(LucideIcons.send, color: t.accent, size: 24), onPressed: _send),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
