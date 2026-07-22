import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

class WindowButtons extends StatefulWidget {
  final bool isDark;

  const WindowButtons({Key? key, required this.isDark}) : super(key: key);

  @override
  State<WindowButtons> createState() => _WindowButtonsState();
}

class _WindowButtonsState extends State<WindowButtons> {
  @override
  Widget build(BuildContext context) {
    final iconColor = widget.isDark ? Colors.white70 : Colors.black87;
    final mouseOverColor = widget.isDark ? Colors.white12 : Colors.black12;

    final buttonColors = WindowButtonColors(
      iconNormal: iconColor,
      mouseOver: mouseOverColor,
      mouseDown: widget.isDark ? Colors.white24 : Colors.black26,
      iconMouseOver: iconColor,
    );

    final closeButtonColors = WindowButtonColors(
      iconNormal: iconColor,
      mouseOver: Colors.redAccent,
      mouseDown: Colors.red,
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
            // Тот самый пункт 1, окно скрывается, а не умирает
            appWindow.hide();
          },
        ),
      ],
    );
  }
}