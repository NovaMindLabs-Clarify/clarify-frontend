import 'dart:io';

import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

import '../core/app_settings.dart';
import '../core/theme/design_tokens.dart';

class WindowButtons extends StatefulWidget {
  final bool isDark;

  const WindowButtons({Key? key, required this.isDark}) : super(key: key);

  @override
  State<WindowButtons> createState() => _WindowButtonsState();
}

class _WindowButtonsState extends State<WindowButtons> {
  @override
  Widget build(BuildContext context) {
    // Через токены, а не через Colors.white70/redAccent: на тёплой палитре
    // (2026-09-04) холодный серый и стоковый красный выбивались из шапки —
    // единственное место в окне, где это было заметно сразу.
    final t = context.tokens;
    final iconColor = t.text2;

    final buttonColors = WindowButtonColors(
      iconNormal: iconColor,
      mouseOver: t.accentSoft,
      mouseDown: t.borderStrong,
      iconMouseOver: t.text,
    );

    final closeButtonColors = WindowButtonColors(
      iconNormal: iconColor,
      mouseOver: t.danger,
      mouseDown: t.danger.withValues(alpha: 0.85),
      iconMouseOver: Colors.white,
    );

    return Row(
      children: [
        MinimizeWindowButton(colors: buttonColors),
        
        WindowButton(
          colors: buttonColors,
          iconBuilder: (buttonContext) {
            if (appWindow.isMaximized) {
              return RestoreIcon(color: buttonContext.iconColor); 
            }
            return MaximizeIcon(color: buttonContext.iconColor); 
          },
          onPressed: () {
            appWindow.maximizeOrRestore();
            setState(() {});
          },
        ),
        
        WindowButton(
          colors: closeButtonColors,
          iconBuilder: (buttonContext) => CloseIcon(color: buttonContext.iconColor),
          onPressed: () {
            // Тот самый пункт 1, окно скрывается, а не умирает —
            // если пользователь отключил "закрытие в трей" в настройках,
            // ведём себя как пункт "Выход" в меню трея.
            if (AppSettings.closeToTray) {
              appWindow.hide();
            } else {
              exit(0);
            }
          },
        ),
      ],
    );
  }
}