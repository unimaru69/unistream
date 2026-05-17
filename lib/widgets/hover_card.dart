import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/colors.dart';
import '../core/design_tokens.dart';

/// Apple-TV+-style focusable / hoverable card.
///
/// Mirrors the tvOS `FocusableCard` + `tvCard` button-style treatment in
/// `tvos/UniStreamTV/UniStreamTV/Views/Components/`: scale up, drop a
/// soft shadow, and overlay a thin teal accent ring when active.
///
/// Active = hover (desktop) **or** keyboard focus (any platform) **or**
/// `forceActive` set externally (used by the "card centered in
/// horizontal viewport" pattern on iOS / iPadOS, where there's no hover
/// concept and the parent row decides which child is currently in
/// focus). All three sources fire `onActiveChange` so a parent can
/// react — typically by updating a wallpaper / backdrop preview.
///
/// On tap, fires `onTap`. Tap-down briefly scales to 0.97 so even
/// without hover the user gets a press confirmation.
class HoverCard extends StatefulWidget {
  const HoverCard({
    super.key,
    required this.child,
    this.onTap,
    this.onActiveChange,
    this.cornerRadius,
    this.autofocus = false,
    this.forceActive = false,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// Fired whenever the active state flips. Active = hover, focus, or
  /// `forceActive`. Use this to drive ambient previews (wallpaper,
  /// info strip) without coupling the parent to hover details.
  final ValueChanged<bool>? onActiveChange;

  /// Defaults to `DS.radius.card` (12 pt).
  final double? cornerRadius;

  /// Request keyboard focus on first build. Useful for the "first card
  /// of a row" pattern when entering a screen.
  final bool autofocus;

  /// External active trigger — set true when the parent decides this
  /// card is the "current" one (e.g. centered in a horizontal scroll
  /// viewport on iPad). Hover and focus take precedence visually but
  /// `forceActive` still emits `onActiveChange`.
  final bool forceActive;

  final String? semanticLabel;

  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  bool get _active => _hovered || _focused || widget.forceActive;

  bool _lastEmitted = false;

  void _emit() {
    final active = _active;
    if (active == _lastEmitted) return;
    _lastEmitted = active;
    widget.onActiveChange?.call(active);
  }

  @override
  void didUpdateWidget(HoverCard old) {
    super.didUpdateWidget(old);
    if (old.forceActive != widget.forceActive) _emit();
  }

  void _handleHover(bool hovered) {
    if (_hovered == hovered) return;
    setState(() => _hovered = hovered);
    _emit();
  }

  void _handleFocus(bool focused) {
    if (_focused == focused) return;
    setState(() => _focused = focused);
    _emit();
  }

  void _handlePress(bool pressed) {
    if (_pressed == pressed) return;
    setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.cornerRadius ?? DS.radius.card;
    final scale = _pressed
        ? 0.97
        : (_active ? DS.focus.cardScale : 1.0);

    return Semantics(
      label: widget.semanticLabel,
      button: widget.onTap != null,
      focusable: true,
      focused: _focused,
      child: FocusableActionDetector(
        autofocus: widget.autofocus,
        mouseCursor: widget.onTap != null
            ? SystemMouseCursors.click
            : MouseCursor.defer,
        onShowHoverHighlight: _handleHover,
        onShowFocusHighlight: _handleFocus,
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
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: widget.onTap == null ? null : (_) => _handlePress(true),
          onTapUp: widget.onTap == null ? null : (_) => _handlePress(false),
          onTapCancel: widget.onTap == null ? null : () => _handlePress(false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: scale,
            duration: DS.focus.animation,
            curve: DS.focus.curve,
            child: AnimatedContainer(
              duration: DS.focus.animation,
              curve: DS.focus.curve,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                boxShadow: _active
                    ? <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: DS.focus.shadowOpacity,
                          ),
                          blurRadius: DS.focus.shadowRadius,
                          offset: Offset(0, DS.focus.shadowY),
                        ),
                      ]
                    : null,
                border: Border.all(
                  color: AppColors.primaryBlue.withValues(
                    alpha: _active ? 0.7 : 0,
                  ),
                  width: DS.focus.ringWidth,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
