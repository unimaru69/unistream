import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'form_factor.dart';

/// Foundation for D-pad (Android TV) focus navigation.
///
/// Wrap a screen's content in a [TvFocusScope]. On non-TV platforms it's a
/// transparent pass-through (zero overhead). On Android TV it:
///
/// 1. **Scopes traversal** — wraps the subtree in a [FocusTraversalGroup]
///    so directional (arrow / D-pad) traversal stays inside this screen.
/// 2. **Plants initial focus** — after the first frame it moves focus onto
///    the first focusable descendant (`nextFocus`), retrying while content
///    is still loading (async lists start empty, so the first attempts
///    find nothing).
/// 3. **Auto-heals** — the app was built pointer-first: many widgets use
///    implicit [FocusNode]s and the UI rebuilds often (connectivity,
///    ambient wallpaper, TMDB lookups, AnimatedSwitcher). When a rebuild
///    *replaces* the focused widget, its node is disposed and
///    `primaryFocus` falls to null — which kills directional traversal
///    (it needs a focused child as a geometric anchor). This listener
///    re-seeds focus on the next frame whenever it drops to null / a bare
///    scope, so the remote never gets "stuck".
///
/// ## Known limitations (the real "chantier")
/// - Re-seeding lands on the *first* focusable, not the previously focused
///   item. To preserve position across rebuilds you need **content-keyed
///   focus restoration** (remember "the tile for item X" and restore to
///   it), which requires stable, owned [FocusNode]s on the navigable
///   widgets rather than the implicit ones `FocusableActionDetector`
///   creates. That is the next layer to build on top of this.
/// - Nested horizontal `ListView`s inside a vertical `ListView` can defeat
///   the default [ReadingOrderTraversalPolicy]; per-row
///   [FocusTraversalGroup]s and/or a custom 2-D policy may be needed.
/// - Lazy `ListView`/`GridView` only build on-screen items, so focus can't
///   traverse to an off-screen tile until it's scrolled into view. Pair
///   D-pad movement with `Scrollable.ensureVisible` (the grid already
///   does this).
class TvFocusScope extends StatefulWidget {
  const TvFocusScope({super.key, required this.child});

  final Widget child;

  @override
  State<TvFocusScope> createState() => _TvFocusScopeState();
}

class _TvFocusScopeState extends State<TvFocusScope> {
  bool _healScheduled = false;

  @override
  void initState() {
    super.initState();
    if (FormFactorInfo.isAndroidTv) {
      FocusManager.instance.addListener(_onFocusChanged);
      WidgetsBinding.instance.addPostFrameCallback((_) => _seed());
    }
  }

  @override
  void dispose() {
    if (FormFactorInfo.isAndroidTv) {
      FocusManager.instance.removeListener(_onFocusChanged);
    }
    super.dispose();
  }

  bool get _hasRealFocus {
    final pf = FocusManager.instance.primaryFocus;
    return pf != null && pf is! FocusScopeNode && pf.context != null;
  }

  /// Routes below a pushed page stay mounted, so their TvFocusScope's
  /// FocusManager listener stays alive too. Without this guard, a covered
  /// screen's auto-heal steals focus back into its own (hidden) subtree
  /// and fights the topmost route — seen as the IME popping open "for
  /// nothing" in a loop on the magic-link page. Only the *current* route
  /// may seed/heal.
  bool get _routeIsCurrent {
    final route = ModalRoute.of(context);
    return route == null || route.isCurrent;
  }

  /// Retry-seed initial focus until a real node sticks (content loads
  /// async, so early frames have nothing focusable).
  void _seed([int attempt = 0]) {
    if (!mounted || !_routeIsCurrent || _hasRealFocus) return;
    final moved = FocusScope.of(context).nextFocus();
    if (!moved && attempt < 20) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _seed(attempt + 1));
    }
  }

  /// When focus collapses to null / a bare scope (rebuild disposed the
  /// focused node), re-plant it on the next frame. Debounced so we don't
  /// fight transient states mid-frame.
  void _onFocusChanged() {
    if (!mounted || _hasRealFocus || _healScheduled) return;
    _healScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _healScheduled = false;
      if (mounted && _routeIsCurrent && !_hasRealFocus) _seed();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!FormFactorInfo.isAndroidTv) return widget.child;
    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: widget.child,
    );
  }
}

/// Makes a [TextField] D-pad friendly on Android TV. No-op elsewhere.
///
/// The core problem this solves: Flutter opens the on-screen keyboard
/// **the moment a text field gains focus**. On a phone that's what a tap
/// means; on TV, D-pad traversal *passes through* fields, so every step
/// through a form popped the fullscreen IME, which then captured the
/// D-pad — the "keyboard opens out of nowhere and keeps coming back"
/// loop. The native leanback pattern is: a text field is an inert focus
/// stop, and the keyboard only opens on an explicit OK press.
///
/// This wrapper implements that pattern around an unmodified child field:
///
/// - It owns a focusable **guard node** that becomes the traversal stop.
///   The inner `EditableText`'s node is marked `skipTraversal` (found by
///   walking descendants each frame), so arrows can never wander into
///   the field by themselves — and therefore never open the IME.
/// - A focus ring is painted around the child when the guard is focused,
///   since the field's own focused border only lights up while editing.
/// - **OK / Enter / D-pad-center** on the guard focuses the inner field,
///   which opens the keyboard (and re-shows it if the field is already
///   focused after the user closed the IME with Back).
/// - While editing, **Up/Down** escape the field into directional focus
///   traversal (the caret keeps Left/Right); falling back to reading
///   order so the user is never trapped.
///
/// Programmatic `FocusNode.requestFocus()` on the field (IME "Next"
/// chaining between fields) still works: `skipTraversal` only hides the
/// node from *traversal*, not from explicit requests.
class TvArrowEscape extends StatefulWidget {
  const TvArrowEscape({super.key, this.guardNode, required this.child});

  /// Optional externally-owned node for the guard, so a host screen can
  /// programmatically land D-pad focus on this field's guard (e.g. after
  /// a PageView transition). The caller keeps ownership/disposal.
  final FocusNode? guardNode;

  final Widget child;

  @override
  State<TvArrowEscape> createState() => _TvArrowEscapeState();
}

class _TvArrowEscapeState extends State<TvArrowEscape> {
  FocusNode? _ownedGuard;
  FocusNode get _guard => widget.guardNode ??
      (_ownedGuard ??= FocusNode(debugLabel: 'TvArrowEscape'));
  bool _guardFocused = false;

  @override
  void dispose() {
    _ownedGuard?.dispose();
    super.dispose();
  }

  /// The inner field's real focus node (the `EditableText`'s), if built.
  ///
  /// The node is hosted by a plain `Focus` widget *inside* EditableText's
  /// build, so `context.widget` is `Focus` — the reliable discriminator is
  /// having an [EditableTextState] ancestor (the suffix icon button's node
  /// doesn't: the decoration is a sibling branch of the editable).
  FocusNode? get _fieldNode {
    for (final d in _guard.descendants) {
      final ctx = d.context;
      if (ctx != null &&
          ctx.findAncestorStateOfType<EditableTextState>() != null) {
        return d;
      }
    }
    return null;
  }

  bool get _editing {
    final primary = FocusManager.instance.primaryFocus;
    return primary != null && primary != _guard && _guard.hasFocus;
  }

  /// Keep the inner field out of D-pad traversal. Descendant nodes are
  /// recreated on rebuilds, so re-apply after every frame.
  void _applySkipTraversal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _fieldNode?.skipTraversal = true;
    });
  }

  void _startEditing() {
    final field = _fieldNode;
    if (field == null) return;
    if (field.hasPrimaryFocus) {
      // Field already holds focus but the user closed the IME with Back
      // — focusing again is a no-op, so re-show the keyboard explicitly.
      SystemChannels.textInput.invokeMethod('TextInput.show');
    } else {
      field.requestFocus();
    }
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;

    // OK / center / enter on the inert guard → enter edit mode. While
    // editing, let enter reach the field (fires onSubmitted / IME action).
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (!_editing && event is KeyDownEvent) {
        _startEditing();
        return KeyEventResult.handled;
      }
      if (_editing && key == LogicalKeyboardKey.select &&
          event is KeyDownEvent) {
        // D-pad center while editing with the IME closed: bring it back.
        SystemChannels.textInput.invokeMethod('TextInput.show');
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    // Up/Down while editing: escape the caret into focus traversal.
    // (While merely guard-focused, returning ignored lets the app-level
    // DirectionalFocusIntent shortcuts traverse normally.)
    if (!_editing) return KeyEventResult.ignored;
    TraversalDirection? dir;
    if (key == LogicalKeyboardKey.arrowDown) dir = TraversalDirection.down;
    if (key == LogicalKeyboardKey.arrowUp) dir = TraversalDirection.up;
    if (dir == null) return KeyEventResult.ignored;
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null) return KeyEventResult.ignored;
    final scope = primary.nearestScope;
    final moved = primary.focusInDirection(dir);
    if (!moved) {
      dir == TraversalDirection.down
          ? primary.nextFocus()
          : primary.previousFocus();
    }
    // CRITICAL: escaping recorded the *field* as the directional-policy
    // history origin. Pressing the opposite direction later would pop
    // that history and hand focus straight back to the field — bypassing
    // skipTraversal entirely (framework behaviour) — reopening the IME
    // out of nowhere. Drop the history so the field stays inert.
    if (scope != null && primary.context != null) {
      FocusTraversalGroup.of(primary.context!).invalidateScopeData(scope);
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    if (!FormFactorInfo.isAndroidTv) return widget.child;
    _applySkipTraversal();
    return Focus(
      focusNode: _guard,
      onFocusChange: (f) {
        if (mounted && f != _guardFocused) setState(() => _guardFocused = f);
      },
      onKeyEvent: _onKeyEvent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            width: 2.5,
            // Ring only while the guard itself is focused — during
            // editing the field's own focused border takes over.
            color: _guardFocused && !_editing
                ? const Color(0xFF1B6B8A)
                : const Color(0x00000000),
          ),
        ),
        child: widget.child,
      ),
    );
  }
}
