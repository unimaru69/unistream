import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/colors.dart';
import '../core/design_tokens.dart';
import '../core/typography.dart';

/// Primary call-to-action used in detail-view hero blocks (VOD, Series).
/// Pill-shaped, accent-teal fill by default, white-on-black on hover /
/// focus — same focus inversion as the tvOS [`PrimaryHeroButton`]
/// (`tvos/.../HeroButtonStyles.swift`) so the cross-platform language
/// stays consistent.
///
/// Reads as the "what to do next" choice on the screen — pair with
/// [GhostHeroButton] for secondary actions of equal weight.
class PrimaryHeroButton extends StatefulWidget {
  const PrimaryHeroButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.autofocus = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool autofocus;

  @override
  State<PrimaryHeroButton> createState() => _PrimaryHeroButtonState();
}

class _PrimaryHeroButtonState extends State<PrimaryHeroButton> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  bool get _active => _hovered || _focused;

  void _setHover(bool v) {
    if (_hovered == v) return;
    setState(() => _hovered = v);
  }

  void _setFocus(bool v) {
    if (_focused == v) return;
    setState(() => _focused = v);
  }

  void _setPress(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final fill = _active ? Colors.white : AppColors.primaryBlue;
    final fg = _active ? Colors.black : Colors.white;
    final scale =
        _pressed ? 0.97 : (_active ? 1.06 : 1.0);
    final enabled = widget.onPressed != null;

    return _HeroButtonShell(
      autofocus: widget.autofocus,
      enabled: enabled,
      onPressed: widget.onPressed,
      onHover: _setHover,
      onFocus: _setFocus,
      onPressChange: _setPress,
      child: AnimatedScale(
        scale: scale,
        duration: DS.focus.animation,
        curve: DS.focus.curve,
        child: AnimatedContainer(
          duration: DS.focus.animation,
          curve: DS.focus.curve,
          padding: EdgeInsets.symmetric(
            horizontal: DS.space.xl,
            vertical: DS.space.sm,
          ),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(DS.radius.pill),
            boxShadow: _active
                ? <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: _HeroButtonContent(
            label: widget.label,
            icon: widget.icon,
            color: fg,
          ),
        ),
      ),
    );
  }
}

/// Secondary action — translucent fill, lifts on hover / focus. Holds an
/// optional [activeTint] that takes over when [isActive] is true (heart
/// filled / bookmark filled / etc.) so the user can see at a glance
/// what's already toggled. Mirror of tvOS `GhostHeroButton`.
class GhostHeroButton extends StatefulWidget {
  const GhostHeroButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.activeTint,
    this.isActive = false,
    this.autofocus = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  /// Colour used when [isActive] is true. Falls back to accent teal.
  final Color? activeTint;

  /// Toggle-state hint — passes through from the call-site so the
  /// chip can render filled when the user has already favourited /
  /// watchlisted / etc.
  final bool isActive;
  final bool autofocus;

  @override
  State<GhostHeroButton> createState() => _GhostHeroButtonState();
}

class _GhostHeroButtonState extends State<GhostHeroButton> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  bool get _active => _hovered || _focused;

  void _setHover(bool v) {
    if (_hovered == v) return;
    setState(() => _hovered = v);
  }

  void _setFocus(bool v) {
    if (_focused == v) return;
    setState(() => _focused = v);
  }

  void _setPress(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final tint = widget.activeTint ?? AppColors.primaryBlue;
    final baseFill = widget.isActive
        ? tint.withValues(alpha: 0.85)
        : Colors.white.withValues(alpha: 0.10);
    final fill = _active ? Colors.white : baseFill;
    final fg = _active ? Colors.black : Colors.white;
    final scale = _pressed ? 0.97 : (_active ? 1.05 : 1.0);
    final enabled = widget.onPressed != null;

    return _HeroButtonShell(
      autofocus: widget.autofocus,
      enabled: enabled,
      onPressed: widget.onPressed,
      onHover: _setHover,
      onFocus: _setFocus,
      onPressChange: _setPress,
      child: AnimatedScale(
        scale: scale,
        duration: DS.focus.animation,
        curve: DS.focus.curve,
        child: AnimatedContainer(
          duration: DS.focus.animation,
          curve: DS.focus.curve,
          padding: EdgeInsets.symmetric(
            horizontal: DS.space.lg,
            vertical: DS.space.sm,
          ),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(DS.radius.pill),
          ),
          child: _HeroButtonContent(
            label: widget.label,
            icon: widget.icon,
            color: fg,
          ),
        ),
      ),
    );
  }
}

class _HeroButtonContent extends StatelessWidget {
  const _HeroButtonContent({
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(icon, size: 20, color: color),
          SizedBox(width: DS.space.xs),
        ],
        Text(
          label,
          style: DSText.bodyEmphasised.copyWith(color: color),
        ),
      ],
    );
  }
}

/// Shared focus / hover / tap plumbing for [PrimaryHeroButton] and
/// [GhostHeroButton]. Keeps the visual shells declarative.
class _HeroButtonShell extends StatelessWidget {
  const _HeroButtonShell({
    required this.child,
    required this.enabled,
    required this.onPressed,
    required this.onHover,
    required this.onFocus,
    required this.onPressChange,
    required this.autofocus,
  });

  final Widget child;
  final bool enabled;
  final VoidCallback? onPressed;
  final ValueChanged<bool> onHover;
  final ValueChanged<bool> onFocus;
  final ValueChanged<bool> onPressChange;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: FocusableActionDetector(
        autofocus: autofocus,
        enabled: enabled,
        mouseCursor: enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onShowHoverHighlight: onHover,
        onShowFocusHighlight: onFocus,
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              onPressed?.call();
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
          onTapDown: enabled ? (_) => onPressChange(true) : null,
          onTapUp: enabled ? (_) => onPressChange(false) : null,
          onTapCancel: enabled ? () => onPressChange(false) : null,
          onTap: onPressed,
          child: child,
        ),
      ),
    );
  }
}
