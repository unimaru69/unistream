import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Behaviour-only focus wrapper for D-pad (Android TV) and keyboard
/// navigation.
///
/// Unlike [HoverCard], this adds **no** visual treatment of its own — it
/// simply makes [child] focus-traversable, activates it on
/// Enter / Space / D-pad-center, and reports focus gain/loss through
/// [onFocusChange]. Callers route [onFocusChange] into whatever hover
/// state already drives their bespoke highlight (scale / shadow / ambient
/// wallpaper), so a tile lights up identically whether reached by mouse
/// hover or by the remote.
///
/// Use this to retrofit existing `GestureDetector` / `MouseRegion` tiles
/// for the 10-foot UI without rewriting their visuals. For brand-new
/// cards that want the standard Apple-TV+ scale+ring treatment, prefer
/// [HoverCard] instead.
class DpadFocusable extends StatelessWidget {
  const DpadFocusable({
    super.key,
    required this.child,
    this.onTap,
    this.onFocusChange,
    this.autofocus = false,
    this.focusNode,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// Fires `true` when this gains focus, `false` when it loses it.
  /// Highlight strategy is forced to traditional on TV (see `main.dart`)
  /// so this fires reliably from the first frame.
  final ValueChanged<bool>? onFocusChange;

  /// Request focus on first build — set on the first item of a grid/row
  /// so the D-pad has a starting point.
  final bool autofocus;

  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      focusNode: focusNode,
      autofocus: autofocus,
      mouseCursor:
          onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            onTap?.call();
            return null;
          },
        ),
      },
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
        // D-pad center on Android TV / leanback remotes.
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
      },
      onShowFocusHighlight: (focused) => onFocusChange?.call(focused),
      child: child,
    );
  }
}
