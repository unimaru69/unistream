import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Wraps its [child] in a [Focus] widget that handles global keyboard
/// shortcuts for the home screen (Cmd/Ctrl + Q, F, Y, G, comma, ?, /).
class HomeKeyboardHandler extends StatelessWidget {
  const HomeKeyboardHandler({
    super.key,
    required this.child,
    required this.onSettings,
    required this.onSearch,
    required this.onHistory,
    required this.onEpgGrid,
    required this.onShortcutsHelp,
    this.selectedCategory,
    this.isLiveMode = false,
  });

  final Widget child;
  final VoidCallback onSettings;
  final VoidCallback onSearch;
  final VoidCallback onHistory;
  final VoidCallback onEpgGrid;
  final VoidCallback onShortcutsHelp;
  final String? selectedCategory;
  final bool isLiveMode;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final mod = Platform.isMacOS
            ? HardwareKeyboard.instance.isMetaPressed
            : HardwareKeyboard.instance.isControlPressed;
        if (!mod) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.keyQ) {
          exit(0);
        }
        if (key == LogicalKeyboardKey.comma) {
          onSettings();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.keyF) {
          onSearch();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.keyY) {
          onHistory();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.keyG) {
          onEpgGrid();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.slash ||
            key == LogicalKeyboardKey.question) {
          onShortcutsHelp();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}
