import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/theme/design_tokens.dart';
import 'clarify_glass.dart';

/// Замена `ScaffoldMessenger.showSnackBar` — компактная плашка в стекле,
/// не на всю ширину экрана (REDESIGN_V3_PLAN.md §3.4/5.4). Overlay поверх
/// корневого Navigator, не требует Scaffold-предка. Один активный тост:
/// новый сразу сменяет предыдущий, а не встаёт в очередь позади него.
enum ClarifyToastVariant { info, success, danger, warning }

class ClarifyToast {
  ClarifyToast._();

  static OverlayEntry? _current;
  static Timer? _timer;
  static VoidCallback? _dismissCurrent;

  static void show(
    BuildContext context,
    String message, {
    ClarifyToastVariant variant = ClarifyToastVariant.info,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _timer?.cancel();
    _current?.remove();
    _current = null;
    _dismissCurrent = null;

    final overlay = Overlay.of(context, rootOverlay: true);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    late final OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _ToastOverlay(
        message: message,
        variant: variant,
        isDark: isDark,
        actionLabel: actionLabel,
        onAction: onAction,
        registerDismiss: (cb) => _dismissCurrent = cb,
        onFullyDismissed: () {
          entry.remove();
          if (identical(_current, entry)) {
            _current = null;
            _dismissCurrent = null;
          }
        },
      ),
    );

    _current = entry;
    overlay.insert(entry);
    _timer = Timer(duration, () => _dismissCurrent?.call());
  }
}

class _ToastOverlay extends StatefulWidget {
  final String message;
  final ClarifyToastVariant variant;
  final bool isDark;
  final String? actionLabel;
  final VoidCallback? onAction;
  final void Function(VoidCallback dismiss) registerDismiss;
  final VoidCallback onFullyDismissed;

  const _ToastOverlay({
    required this.message,
    required this.variant,
    required this.isDark,
    this.actionLabel,
    this.onAction,
    required this.registerDismiss,
    required this.onFullyDismissed,
  });

  @override
  State<_ToastOverlay> createState() => _ToastOverlayState();
}

class _ToastOverlayState extends State<_ToastOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: ClarifyMotion.base)..forward();
    widget.registerDismiss(_dismiss);
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    await _controller.reverse();
    widget.onFullyDismissed();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  (Color, IconData) _variantStyle(ClarifyTokens t) {
    switch (widget.variant) {
      case ClarifyToastVariant.success:
        return (t.success, LucideIcons.circleCheck);
      case ClarifyToastVariant.danger:
        return (t.danger, LucideIcons.circleAlert);
      case ClarifyToastVariant.warning:
        return (t.warning, LucideIcons.triangleAlert);
      case ClarifyToastVariant.info:
        return (t.accent, LucideIcons.info);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.isDark ? ClarifyTokens.dark : ClarifyTokens.light;
    final (accentColor, icon) = _variantStyle(t);
    final curved = CurvedAnimation(parent: _controller, curve: ClarifyMotion.standard);

    return Positioned(
      left: 24,
      right: 24,
      bottom: 32,
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(curved),
              child: GestureDetector(
                onTap: _dismiss,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: ClarifyGlass(
                    borderRadius: BorderRadius.circular(ClarifyRadius.pill),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 20, color: accentColor),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            widget.message,
                            style: TextStyle(color: t.text, fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                        ),
                        if (widget.actionLabel != null) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              widget.onAction?.call();
                              _dismiss();
                            },
                            child: Text(
                              widget.actionLabel!,
                              style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
