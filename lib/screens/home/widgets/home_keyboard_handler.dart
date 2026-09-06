import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/form_factor.dart';

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
      // Desktop: this whole-screen Focus holds default focus so the
      // Ctrl/Cmd shortcuts work before anything is clicked. On Android
      // TV it must be a PURE interceptor: if it can take focus, the
      // TvFocusScope seeding lands on it (first node in reading order),
      // which satisfies "something has focus" with an invisible
      // full-screen node — and directional traversal from a rect that
      // covers the screen goes nowhere. Dead D-pad.
      autofocus: !FormFactorInfo.isAndroidTv,
      canRequestFocus: !FormFactorInfo.isAndroidTv,
      skipTraversal: FormFactorInfo.isAndroidTv,
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
