import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/localization.dart';
import '../core/theme/design_tokens.dart';
import '../screens/desktop_planner_screen.dart' show AiParseHttpException;
import '../widgets/clarify_illustrations.dart';
import '../widgets/clarify_surface.dart';
import '../widgets/voice_record_button.dart';

/// Модальный чат с ИИ-ассистентом, открываемый кнопкой ИИ из диалога "Новая
/// задача" (showManualAddDialog) — по аналогии с мобильной версией (там
/// иконка-искра открывает ассистента), но с иным поведением: не полноэкранная
/// навигация, а окошко того же размера, что и сам диалог создания задачи.
/// Закрытие этого окна (крестик) закрывает и диалог "Новая задача" под ним —
/// пользователю больше не нужна ручная форма, раз он вёл диалог с
/// ассистентом (подтверждено пользователем явно: "Окно новая задача тоже
/// закрывается").
void showManualAddAiChatDialog({
  required BuildContext context,
  required String currentLang,
  required Color textColor,
  required Color textMuted,
  required Future<String> Function(String text, List<Map<String, String>> history)
  onAiParseText,
  required Future<String> Function(
    Uint8List audioBytes,
    String filename,
    String contentType,
  )
  onTranscribeVoice,
  required Widget Function({
    required Widget child,
    BorderRadius? borderRadius,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    Color? customColor,
  })
  buildGlassContainer,
}) {
  showClarifyResponsiveSurface(
    context: context,
    barrierColor: Colors.black.withOpacity(0.4),
    builder: (context) {
      final content = _ManualAddAiChatContent(
        currentLang: currentLang,
        textColor: textColor,
        textMuted: textMuted,
        onAiParseText: onAiParseText,
        onTranscribeVoice: onTranscribeVoice,
      );

      if (isClarifyDialogMobile(context)) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            4,
            20,
            MediaQuery.of(context).padding.bottom + 20,
          ),
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.7,
            child: content,
          ),
        );
      }
      return Center(
        child: Material(
          color: Colors.transparent,
          child: buildGlassContainer(
            borderRadius: ClarifyRadius.dialogShell,
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: (MediaQuery.sizeOf(context).width - 80).clamp(280.0, 450.0),
              height: 520,
              child: content,
            ),
          ),
        ),
      );
    },
  );
}

class _ManualAddAiChatContent extends StatefulWidget {
  final String currentLang;
  final Color textColor;
  final Color textMuted;
  final Future<String> Function(String text, List<Map<String, String>> history)
  onAiParseText;
  final Future<String> Function(
    Uint8List audioBytes,
    String filename,
    String contentType,
  )
  onTranscribeVoice;

  const _ManualAddAiChatContent({
    required this.currentLang,
    required this.textColor,
    required this.textMuted,
    required this.onAiParseText,
    required this.onTranscribeVoice,
  });

  @override
  State<_ManualAddAiChatContent> createState() => _ManualAddAiChatContentState();
}

class _ManualAddAiChatContentState extends State<_ManualAddAiChatContent> {
  final List<Map<String, String>> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  // overrideText/displayText — для голосовых сообщений (_sendVoiceMessage),
  // тот же приём, что и на десктопной AI-панели/мобильном AI-экране.
  Future<void> _send({String? overrideText, String? displayText}) async {
    final text = (overrideText ?? _controller.text).trim();
    if (text.isEmpty || _isTyping) return;
    const historyLimit = 8;
    final history = _messages.length > historyLimit
        ? _messages.sublist(_messages.length - historyLimit)
        : List<Map<String, String>>.from(_messages);
    setState(() {
      _messages.add({'role': 'user', 'text': (displayText ?? text).trim()});
      _isTyping = true;
    });
    if (overrideText == null) _controller.clear();
    _scrollToBottom();
    try {
      final reply = await widget.onAiParseText(text, history);
      if (!mounted) return;
      setState(() {
        _messages.add({'role': 'ai', 'text': reply});
        _isTyping = false;
      });
    } on AiParseHttpException catch (e) {
      if (!mounted) return;
      final body = e.body.substring(0, e.body.length > 120 ? 120 : e.body.length);
      setState(() {
        _messages.add({'role': 'ai', 'text': 'Ошибка: сервер вернул ${e.statusCode} ($body)'});
        _isTyping = false;
      });
    } catch (e) {
      if (!mounted) return;
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
    } catch (e) {
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

  void _closeAll() {
    // Закрывает и это модальное окно, и диалог "Новая задача" под ним — обе
    // подряд, т.к. они соседние маршруты в одном и том же навигаторе
    // (showClarifyResponsiveSurface толкает свой маршрут поверх маршрута
    // showManualAddDialog).
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.pop();
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(LucideIcons.sparkles, color: t.accent, size: 22),
                const SizedBox(width: 8),
                Text(
                  'AI Ассистент'.tr(widget.currentLang),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: widget.textColor),
                ),
              ],
            ),
            IconButton(
              icon: Icon(LucideIcons.x, color: widget.textMuted),
              onPressed: _closeAll,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const ClarifyIllustration(type: ClarifyIllustrationType.aiSpark, size: 64),
                        const SizedBox(height: 16),
                        Text(
                          'Опиши задачи текстом или голосом — ИИ сам расставит даты, время и приоритеты.'.tr(widget.currentLang),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: widget.textMuted, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final isAi = msg['role'] == 'ai';
                    return Align(
                      alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        constraints: BoxConstraints(maxWidth: 320),
                        decoration: BoxDecoration(
                          color: isAi ? t.surface2 : t.accent,
                          borderRadius: BorderRadius.circular(14).copyWith(
                            bottomLeft: isAi ? const Radius.circular(0) : const Radius.circular(14),
                            bottomRight: !isAi ? const Radius.circular(0) : const Radius.circular(14),
                          ),
                          border: isAi ? Border.all(color: t.border) : null,
                        ),
                        child: Text(msg['text']!, style: TextStyle(color: isAi ? t.text : t.onAccent, fontSize: 14)),
                      ),
                    );
                  },
                ),
        ),
        if (_isTyping)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Печатает...'.tr(widget.currentLang), style: TextStyle(color: widget.textMuted, fontSize: 13, fontStyle: FontStyle.italic)),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: 4,
                minLines: 1,
                style: TextStyle(color: widget.textColor, fontSize: 14),
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Опиши задачу...'.tr(widget.currentLang),
                  hintStyle: TextStyle(color: widget.textMuted, fontSize: 13),
                  filled: true,
                  fillColor: t.surfaceSunken,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            VoiceRecordButton(currentLang: widget.currentLang, onRecorded: _sendVoiceMessage),
            const SizedBox(width: 4),
            IconButton(icon: Icon(LucideIcons.send, color: t.accent, size: 22), onPressed: _send),
          ],
        ),
      ],
    );
  }
}
