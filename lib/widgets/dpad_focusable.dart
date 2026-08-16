import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/colors.dart';
import '../core/design_tokens.dart';
import '../core/form_factor.dart';

/// Behaviour-only focus wrapper for D-pad (Android TV) and keyboard
/// navigation.
///
/// Makes [child] focus-traversable, activates it on Enter / Space /
/// D-pad-center, and reports focus gain/loss through [onFocusChange].
/// Callers route [onFocusChange] into whatever hover state already drives
/// their bespoke highlight (scale / shadow / ambient wallpaper), so a tile
/// lights up identically whether reached by mouse hover or by the remote.
///
/// On Android TV it also draws a focus ring of its own unless
/// [tvHighlight] is false — see that field for why.
///
/// Use this to retrofit existing `GestureDetector` / `MouseRegion` tiles
/// for the 10-foot UI without rewriting their visuals. For brand-new
/// cards that want the standard Apple-TV+ scale+ring treatment, prefer
/// [HoverCard] instead.
class DpadFocusable extends StatefulWidget {
  const DpadFocusable({
    super.key,
    required this.child,
    this.onTap,
    this.onFocusChange,
    this.autofocus = false,
    this.focusNode,
    this.tvHighlight = true,
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

  /// Draw a focus ring on Android TV.
  ///
  /// This wrapper started out purely behavioural, leaving every visual to
  /// the caller through [onFocusChange]. On a TV that contract breaks
  /// down: call sites that pass no [onFocusChange] — the replay row, for
  /// one — become focusable while showing nothing at all, so the remote
  /// appears to lose focus into a void, and there is no pointer to fall
  /// back on. Hence a ring by default. Pass `false` where the call site
  /// already lights up convincingly on its own.
  final bool tvHighlight;

  @override
  State<DpadFocusable> createState() => _DpadFocusableState();
}

class _DpadFocusableState extends State<DpadFocusable> {
  bool _focused = false;

  bool get _ringEnabled => widget.tvHighlight && FormFactorInfo.isAndroidTv;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      mouseCursor:
          widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap?.call();
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
      onShowFocusHighlight: (focused) {
        widget.onFocusChange?.call(focused);
        if (_ringEnabled && focused != _focused) {
          setState(() => _focused = focused);
        }
      },
      // Ring only — no scale, no animation. These wrap items inside
      // fixed-height rows and carousels, where a scale would be clipped
      // by the viewport, and this box is weak enough that an animated
      // focus treatment in the grid was enough to ANR the app.
      child: _ringEnabled
          ? DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(DS.radius.card),
                border: Border.all(
                  color: AppColors.primaryBlue
                      .withValues(alpha: _focused ? 0.9 : 0),
                  width: DS.focus.ringWidth,
                ),
              ),
              child: widget.child,
            )
          : widget.child,
    );
  }
}
