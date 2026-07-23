import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/localization.dart';
import '../core/theme/design_tokens.dart';

/// Правая выезжающая панель AI-ассистента. Вынесено из DesktopPlannerScreen
/// (P3.1, docs/IMPROVEMENT_PLAN.md) — логика и разметка не менялись, только
/// доступ к состоянию родителя заменён на явные параметры конструктора.
class AiChatPanel extends StatelessWidget {
  final String currentLang;
  final Color textColor;
  final Color textMuted;
  final Color glassBorderColor;
  final Color chatBubbleAi;
  final Color chatInput;
  final List<Map<String, String>> chatMessages;
  final bool isAiTyping;
  final bool isListening;
  final TextEditingController controller;
  final VoidCallback onToggleListening;
  final void Function(String text) onSend;

  const AiChatPanel({
    super.key,
    required this.currentLang,
    required this.textColor,
    required this.textMuted,
    required this.glassBorderColor,
    required this.chatBubbleAi,
    required this.chatInput,
    required this.chatMessages,
    required this.isAiTyping,
    required this.isListening,
    required this.controller,
    required this.onToggleListening,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(padding: const EdgeInsets.fromLTRB(24, 32, 24, 24), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: glassBorderColor))), child: Row(children: [Icon(LucideIcons.sparkles, color: t.accent, size: 28), const SizedBox(width: 12), Text("AI Ассистент".tr(currentLang), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor))])),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(20), itemCount: chatMessages.length,
            itemBuilder: (context, index) {
              final msg = chatMessages[index]; final isAi = msg['role'] == 'ai';
              return Align(alignment: isAi ? Alignment.centerLeft : Alignment.centerRight, child: Container(margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: BoxDecoration(color: isAi ? chatBubbleAi : t.accent, borderRadius: BorderRadius.circular(16).copyWith(bottomLeft: isAi ? const Radius.circular(0) : const Radius.circular(16), bottomRight: !isAi ? const Radius.circular(0) : const Radius.circular(16)), border: isAi ? Border.all(color: glassBorderColor) : null),
              child: Text(msg['text']!.tr(currentLang), style: TextStyle(color: isAi ? textColor : t.onAccent, fontSize: 15))));
            },
          ),
        ),
        if (isAiTyping) Padding(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8), child: Text("Печатает...".tr(currentLang), style: TextStyle(color: textMuted, fontSize: 14, fontStyle: FontStyle.italic))),
        Container(
          padding: const EdgeInsets.all(24), decoration: BoxDecoration(border: Border(top: BorderSide(color: glassBorderColor))),
          child: TextField(
            controller: controller, maxLines: 5, minLines: 1, style: TextStyle(color: textColor, fontSize: 15), keyboardType: TextInputType.multiline,
            decoration: InputDecoration(
              hintText: 'Вставь ТЗ или нажми микрофон...'.tr(currentLang), hintStyle: TextStyle(color: textMuted, fontSize: 14), filled: true, fillColor: chatInput, border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(margin: const EdgeInsets.symmetric(horizontal: 4), decoration: BoxDecoration(color: isListening ? t.dangerSoft : Colors.transparent, shape: BoxShape.circle), child: IconButton(icon: Icon(isListening ? LucideIcons.mic : LucideIcons.micOff, color: isListening ? t.danger : t.accent, size: 24), onPressed: onToggleListening)),
                  IconButton(icon: Icon(LucideIcons.send, color: t.accent, size: 24), onPressed: () => onSend(controller.text)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
