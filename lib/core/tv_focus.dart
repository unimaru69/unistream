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

/// Lets the D-pad escape a focused [TextField] vertically on Android TV.
///
/// A focused `EditableText` consumes arrow keys for caret movement (via
/// `DefaultTextEditingShortcuts` at the app root), so Up/Down can never
/// leave the field — the user gets trapped and can't reach the buttons
/// below the form. Wrapping the field in this widget intercepts Up/Down
/// on the way up the focus chain (we sit *closer to the leaf* than the
/// root shortcuts, so we win) and turns them into directional focus
/// traversal instead. Left/Right are left alone so the caret still moves
/// while editing.
///
/// No-op wrapper off Android TV. Note: when the on-screen keyboard is
/// open, the system IME consumes the D-pad for its own key grid — this
/// only kicks in once the IME is closed (Back) and the field still holds
/// focus.
class TvArrowEscape extends StatelessWidget {
  const TvArrowEscape({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!FormFactorInfo.isAndroidTv) return child;
    return Focus(
      // Pure key-interceptor: never focusable, never a traversal stop.
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }
        final key = event.logicalKey;
        TraversalDirection? dir;
        if (key == LogicalKeyboardKey.arrowDown) dir = TraversalDirection.down;
        if (key == LogicalKeyboardKey.arrowUp) dir = TraversalDirection.up;
        if (dir == null) return KeyEventResult.ignored;
        final primary = FocusManager.instance.primaryFocus;
        if (primary == null) return KeyEventResult.ignored;
        final moved = primary.focusInDirection(dir);
        if (!moved) {
          // Geometric traversal found nothing (off-screen target, odd
          // layout) — fall back to reading order so we never trap.
          dir == TraversalDirection.down
              ? primary.nextFocus()
              : primary.previousFocus();
        }
        // Consume either way so the caret shortcut at the root doesn't
        // also fire.
        return KeyEventResult.handled;
      },
      child: child,
    );
  }
}
