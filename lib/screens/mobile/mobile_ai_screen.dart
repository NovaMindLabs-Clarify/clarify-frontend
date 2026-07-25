import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../core/localization.dart';
import '../../core/theme/design_tokens.dart';
import '../../widgets/clarify_toast.dart';

/// Полноэкранная мобильная версия AI-ассистента (desktop-аналог —
/// `widgets/ai_chat_panel.dart`, встроенный в боковую панель, которой на
/// мобильном нет). Логика разбора текста в задачи (`onParseText`) приходит
/// из DesktopPlannerScreen — тот же `/tasks/parse` эндпоинт и OpenRouter,
/// что и на десктопе, просто с отдельным полноэкранным UI и собственным
/// состоянием чата вместо общего с десктопной панелью.
class MobileAiScreen extends StatefulWidget {
  final String currentLang;
  final Future<int> Function(String text) onParseText;

  const MobileAiScreen({super.key, required this.currentLang, required this.onParseText});

  @override
  State<MobileAiScreen> createState() => _MobileAiScreenState();
}

class _MobileAiScreenState extends State<MobileAiScreen> {
  final List<Map<String, String>> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;
  bool _isListening = false;
  bool _speechEnabled = false;
  late stt.SpeechToText _speechToText;
  String _localeId = 'ru_RU';

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _speechToText = stt.SpeechToText();
    try {
      _speechEnabled = await _speechToText.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted) setState(() => _isListening = false);
          }
        },
        onError: (_) {
          if (mounted) setState(() => _isListening = false);
        },
      );
      if (_speechEnabled) {
        final systemLocales = await _speechToText.locales();
        final ruLocale = systemLocales.firstWhere(
          (locale) => locale.localeId.toLowerCase().contains('ru'),
          orElse: () => systemLocales.first,
        );
        _localeId = ruLocale.localeId;
      }
      if (mounted) setState(() {});
    } on Exception {
      // Микрофон недоступен (нет разрешения/устройства) — молча остаёмся
      // в режиме "только текст", кнопка микрофона просто не будет работать.
    }
  }

  Future<void> _toggleListening() async {
    if (!_speechEnabled) {
      ClarifyToast.show(context, 'Микрофон недоступен.'.tr(widget.currentLang), variant: ClarifyToastVariant.danger);
      return;
    }
    if (_speechToText.isListening) {
      await _speechToText.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }
    setState(() => _isListening = true);
    final currentText = _controller.text;
    await _speechToText.listen(
      localeId: _localeId,
      onResult: (result) {
        setState(() {
          _controller.text = currentText.isEmpty ? result.recognizedWords : '$currentText ${result.recognizedWords}';
        });
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isTyping) return;
    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isTyping = true;
    });
    _controller.clear();
    _scrollToBottom();
    try {
      final count = await widget.onParseText(text);
      if (!mounted) return;
      setState(() {
        _messages.add({'role': 'ai', 'text': 'Готово! Добавлено задач: $count.'.tr(widget.currentLang)});
        _isTyping = false;
      });
    } on Exception {
      if (!mounted) return;
      setState(() {
        _messages.add({'role': 'ai', 'text': 'Ошибка связи с ИИ.'.tr(widget.currentLang)});
        _isTyping = false;
      });
    }
    _scrollToBottom();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    if (_speechEnabled) _speechToText.stop();
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
                      child: Text(
                        'Опиши задачи текстом или голосом — ИИ сам расставит даты, время и приоритеты.'.tr(widget.currentLang),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: t.text3, fontSize: 15),
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
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(color: _isListening ? t.dangerSoft : Colors.transparent, shape: BoxShape.circle),
                        child: IconButton(
                          icon: Icon(_isListening ? LucideIcons.mic : LucideIcons.micOff, color: _isListening ? t.danger : t.accent, size: 24),
                          onPressed: _toggleListening,
                        ),
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
