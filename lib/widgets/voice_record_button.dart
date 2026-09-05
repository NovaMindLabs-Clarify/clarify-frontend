import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:record/record.dart';

import '../core/localization.dart';
import '../core/theme/design_tokens.dart';
import '../services/voice_audio.dart';
import 'clarify_toast.dart';

/// Кнопка голосового сообщения — нажал-держал-отпустил, как в Telegram/
/// WhatsApp (запись начинается сразу по нажатию, не после долгого тапа).
/// Заменяет прежний speech_to_text (расшифровка вживую по ходу речи прямо в
/// текстовое поле) — теперь по аналогии с Telegram-ботом этого же
/// приложения: запись целиком отправляется на бэкенд (/ai/transcribe-voice),
/// который расшифровывает её через ту же Groq Whisper обёртку
/// (telegram_bot.transcribe_voice), что и бот. Само аудио никуда не
/// сохраняется и не проигрывается — только текст расшифровки.
///
/// AudioEncoder различается по платформе: `record_windows` (Media
/// Foundation) не поддерживает Opus вообще (только AAC/AMR/FLAC/PCM), а
/// веб-версия (MediaRecorder) увереннее всего поддерживает Opus в
/// webm-контейнере в Chrome/Firefox, чем AAC/mp4. Поэтому AAC на десктопе,
/// Opus в вебе — не единый кодек на все платформы.
class VoiceRecordButton extends StatefulWidget {
  final String currentLang;
  final bool enabled;
  final double size;

  /// Вызывается после успешной остановки записи (release, не отмена) с
  /// байтами аудио + именем файла/mime-типом для загрузки на бэкенд.
  final Future<void> Function(
    Uint8List audioBytes,
    String filename,
    String contentType,
  )
  onRecorded;

  const VoiceRecordButton({
    super.key,
    required this.currentLang,
    required this.onRecorded,
    this.enabled = true,
    this.size = 24,
  });

  @override
  State<VoiceRecordButton> createState() => _VoiceRecordButtonState();
}

class _VoiceRecordButtonState extends State<VoiceRecordButton> {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _busy = false;
  Timer? _ticker;
  Duration _elapsed = Duration.zero;

  // Записи короче этого порога отбрасываются молча (случайный тап/дрожь
  // пальца) — то же поведение, что и у мессенджеров вроде Telegram.
  static const _minDuration = Duration(milliseconds: 400);

  AudioEncoder get _encoder => kIsWeb ? AudioEncoder.opus : AudioEncoder.aacLc;
  String get _filename => kIsWeb ? 'voice.webm' : 'voice.m4a';
  String get _contentType => kIsWeb ? 'audio/webm' : 'audio/mp4';

  Future<void> _start() async {
    if (!widget.enabled || _isRecording || _busy) return;
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        ClarifyToast.show(
          context,
          'Микрофон недоступен.'.tr(widget.currentLang),
          variant: ClarifyToastVariant.danger,
        );
      }
      return;
    }
    final path = await prepareRecordingPath();
    await _recorder.start(RecordConfig(encoder: _encoder), path: path);
    if (!mounted) return;
    setState(() {
      _isRecording = true;
      _elapsed = Duration.zero;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  Future<void> _stop({required bool send}) async {
    if (!_isRecording) return;
    _ticker?.cancel();
    _ticker = null;
    final elapsed = _elapsed;
    setState(() {
      _isRecording = false;
      _busy = send;
    });
    final path = await _recorder.stop();
    if (path == null || !send || elapsed < _minDuration) {
      if (mounted) setState(() => _busy = false);
      return;
    }
    try {
      final bytes = await readRecordedBytes(path);
      if (bytes.isEmpty) return;
      await widget.onRecorded(bytes, _filename, _contentType);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  String _formatElapsed(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    if (_isRecording) {
      return GestureDetector(
        onTapUp: (_) => _stop(send: true),
        onTapCancel: () => _stop(send: false),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: t.dangerSoft,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.3, end: 1),
                duration: reduceMotion
                    ? Duration.zero
                    // Собственный ритм пульсации во время записи: он
                    // должен быть заметно медленнее любого UI-перехода,
                    // поэтому своё число, а не токен.
                    : const Duration(milliseconds: 700),
                curve: Curves.easeInOut,
                builder: (context, value, child) => Opacity(
                  opacity: reduceMotion ? 1 : value,
                  child: child,
                ),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: t.danger,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatElapsed(_elapsed),
                style: TextStyle(
                  color: t.danger,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 8),
              Icon(LucideIcons.send, color: t.danger, size: 16),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTapDown: (_) => _start(),
      onTapUp: (_) => _stop(send: true),
      onTapCancel: () => _stop(send: false),
      child: _busy
          ? SizedBox(
              width: widget.size,
              height: widget.size,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: t.accent,
                ),
              ),
            )
          : Icon(
              LucideIcons.mic,
              color: widget.enabled ? t.accent : t.text3,
              size: widget.size,
            ),
    );
  }
}
