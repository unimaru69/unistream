import 'dart:async';

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
  Timer? _seedTimer;

  @override
  void initState() {
    super.initState();
    if (FormFactorInfo.isAndroidTv) {
      FocusManager.instance.addListener(_onFocusChanged);
      WidgetsBinding.instance.addPostFrameCallback((_) => _seed());
      // Persistent seeding. A frame-count retry gives up in ~300 ms, but
      // screens like Home show a skeleton for seconds before the first
      // focusable exists — by then seeding was over and, with no focus
      // change ever happening, the heal never fired either: dead D-pad
      // forever. A slow periodic check (no-op once something has focus)
      // guarantees the remote always gets an anchor eventually.
      _seedTimer = Timer.periodic(
        const Duration(milliseconds: 500),
        (_) => _seed(),
      );
    }
  }

  @override
  void dispose() {
    if (FormFactorInfo.isAndroidTv) {
      FocusManager.instance.removeListener(_onFocusChanged);
    }
    _seedTimer?.cancel();
    super.dispose();
  }

  /// Last node that genuinely held focus, so a heal can put the user
  /// back where they were instead of at the top of the screen.
  FocusNode? _lastRealFocus;

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

  /// Single seeding attempt — re-driven by [_seedTimer] until a real
  /// node sticks (content loads async, so early frames have nothing
  /// focusable), and by the heal listener after focus collapses.
  void _seed() {
    if (!mounted || !_routeIsCurrent || _hasRealFocus) return;
    // Prefer where the user actually was. Healing to the *first*
    // focusable is what made the remote feel possessed: a backdrop or a
    // TMDB lookup finishing mid-navigation replaces the focused widget,
    // focus collapses, and the user is yanked back to the top of the
    // grid — climbing to the app bar became impossible in practice
    // because every attempt was reset partway. Only usable if the node
    // survived the rebuild that dropped focus.
    final last = _lastRealFocus;
    if (last != null && last.context != null && last.canRequestFocus) {
      last.requestFocus();
      return;
    }
    FocusScope.of(context).nextFocus();
  }

  /// When focus collapses to null / a bare scope (rebuild disposed the
  /// focused node), re-plant it on the next frame. Debounced so we don't
  /// fight transient states mid-frame.
  void _onFocusChanged() {
    if (!mounted) return;
    if (_hasRealFocus) {
      _lastRealFocus = FocusManager.instance.primaryFocus;
      return;
    }
    if (_healScheduled) return;
    _healScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _healScheduled = false;
      if (mounted && _routeIsCurrent && !_hasRealFocus) _seed();
    });
  }

  /// Vertical traversal for the D-pad.
  ///
  /// Geometric `focusInDirection` alone strands the remote: climbing out
  /// of a content row towards the app bar finds nothing, because the
  /// row's tiles and the bar don't overlap horizontally the way the
  /// policy expects. We sit above the leaves but below `WidgetsApp`'s
  /// default shortcuts, so text fields (TvArrowEscape) still consume
  /// arrows first; anything reaching us gets geometry first, then a
  /// direction-constrained search.
  ///
  /// What this replaced, and why — traced on a Skyworth box, pressing Up
  /// eleven times from the film grid:
  ///
  ///   y=401   ×6   same tile re-notified: focus pinned, Up did nothing
  ///   y=-110  ×8   tile above the viewport, page never scrolled to it
  ///   y=-218       another off-screen node
  ///   y=637        wrapped to the bottom of the grid
  ///
  /// The old fallback used reading order, which wraps at the ends, and
  /// then undid the wrap with `requestFocus()` on the current node — so
  /// every press cancelled its own move and the user hammered Up into a
  /// dead remote, before finally being thrown to the bottom. Nothing
  /// scrolled either, which is why the hero looked like it was never
  /// reached: focus was sitting on it, off-screen.
  KeyEventResult _onVerticalKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final isDown = key == LogicalKeyboardKey.arrowDown;
    final isUp = key == LogicalKeyboardKey.arrowUp;
    if (!isDown && !isUp) return KeyEventResult.ignored;
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null) return KeyEventResult.ignored;
    final before = primary.rect;

    // Flutter's geometric traversal first. Trying to force a "stay in the
    // column" rule ahead of it was tested and is worse: a same-column
    // candidate can be anywhere higher on the page, including across a
    // zone boundary, so the remote jumped into the category sidebar
    // mid-climb and could no longer come back down into the grid.
    if (primary.focusInDirection(
      isDown ? TraversalDirection.down : TraversalDirection.up,
    )) {
      _revealFocused(up: isUp);
      return KeyEventResult.handled;
    }

    // Geometry found nothing: widen the search, so an edge is never a
    // dead end. Never a wrap-around, though.
    final target = _nearestInDirection(primary, before, up: isUp);
    if (target == null) return KeyEventResult.handled;
    target.requestFocus();
    _revealFocused(up: isUp);
    return KeyEventResult.handled;
  }

  /// Scroll whatever now holds focus back into view.
  ///
  /// Done centrally rather than per widget: the grid scrolled its own
  /// tiles, the carousels and the hero did not, and focus routinely ended
  /// up on nodes above the viewport with the page unmoved. Aligning to
  /// the edge we came from (start when moving up, end when moving down)
  /// scrolls the minimum needed — centring would drag the top of a tall
  /// hero out of frame.
  void _revealFocused({required bool up}) {
    // Deferred on purpose. FocusManager applies a requestFocus() in a
    // microtask, so reading primaryFocus on the next line still returns
    // the node we just left — scrolling the *previous* item into view and
    // leaving the new one off-screen. Traced: focus sat at y=-128 while
    // the page never moved. Waiting for the frame gives us the node that
    // actually holds focus, with its layout settled.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _revealNow(up: up);
    });
  }

  void _revealNow({required bool up}) {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return;
    // Already comfortably on screen? Leave the page alone. Without this
    // the two mechanisms below fight each other every press: ensureVisible
    // nudges the page down to seat the item at 0.2, then the snap pulls it
    // back to the top — the bar visibly bounced up and down on each Up.
    final rect = FocusManager.instance.primaryFocus?.rect;
    if (rect != null) {
      final size = MediaQuery.maybeSizeOf(ctx);
      // Below the (transparent, overlapping) app bar and above the fold.
      const barGuard = 60.0;
      if (size != null &&
          rect.top >= barGuard &&
          rect.bottom <= size.height) {
        return;
      }
    }

    if (up) {
      // Not the viewport edge: the app bar is transparent and the content
      // scrolls *under* it (extendBodyBehindAppBar), so aligning to 0.0
      // parked the focused item at y=0 — hidden behind the bar, and
      // physically above the bar's own buttons, which then made climbing
      // any further impossible. Traced: focus at y=0 while the topmost
      // node in the whole scope was the app bar tab at y=3, so nothing
      // qualified as "above". A fifth of the viewport clears the bar with
      // room to spare and still shows what sits above the target.
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.2,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
      _snapToTopIfClose(ctx);
    } else {
      Scrollable.ensureVisible(
        ctx,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  }

  /// Once the page is nearly at the top, go all the way.
  ///
  /// The 0.2 alignment is right in the middle of a long page but wrong at
  /// its start: reaching the hero parked its Play button a fifth of the
  /// way down and left the hero's own title and artwork above the frame.
  /// Checked after the reveal animation, so we act on where the page
  /// actually ended up.
  void _snapToTopIfClose(BuildContext ctx) {
    // Walk out to the OUTERMOST vertical scrollable: a card inside a
    // carousel sits in a horizontal one, which is not the page. Resolved
    // now, while the context is known good — only the position is touched
    // after the delay.
    ScrollableState? vertical;
    ScrollableState? next = Scrollable.maybeOf(ctx);
    {
      while (next != null) {
        if (next.position.axis == Axis.vertical) vertical = next;
        next = Scrollable.maybeOf(next.context);
      }
    }
    final scrollable = vertical;
    if (scrollable == null) return;
    Future<void>.delayed(const Duration(milliseconds: 220), () {
      if (!mounted || !scrollable.mounted) return;
      final pos = scrollable.position;
      if (!pos.hasPixels) return;
      if (pos.pixels - pos.minScrollExtent >= 400) return;
      pos.animateTo(
        pos.minScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  /// Nearest traversable node strictly above / below [from].
  ///
  /// Ranked by vertical gap first, then horizontal centre distance, so
  /// climbing out of a row lands on the item overhead rather than
  /// whichever one happens to come first in the tree.
  FocusNode? _nearestInDirection(
    FocusNode primary,
    Rect from, {
    required bool up,
    bool alignedOnly = false,
  }) {
    final scope = primary.nearestScope;
    if (scope == null) return null;
    // Two rankings. A candidate that overlaps us horizontally is in the
    // same column and always wins: without that, going Up from the hero
    // landed in the category sidebar — geometrically just above, but on
    // the other side of the screen. Up should stay in the column
    // (grid → hero → app bar); the sidebar is what Left is for. The
    // non-overlapping ranking is only a fallback, so no edge is a dead end.
    FocusNode? best;
    double bestGap = double.infinity;
    double bestDx = double.infinity;
    FocusNode? bestAligned;
    double bestAlignedGap = double.infinity;
    for (final candidate in scope.traversalDescendants) {
      if (candidate == primary ||
          !candidate.canRequestFocus ||
          candidate.skipTraversal) {
        continue;
      }
      final r = candidate.rect;
      if (r.isEmpty) continue;
      // Strictly in the requested direction, with a pixel of tolerance so
      // items merely sharing an edge don't qualify.
      final gap = up ? from.top - r.bottom : r.top - from.bottom;
      if (gap < -1) continue;
      final dx = (r.center.dx - from.center.dx).abs();
      final overlaps = r.right > from.left && r.left < from.right;
      if (overlaps && gap < bestAlignedGap) {
        bestAligned = candidate;
        bestAlignedGap = gap;
      }
      if (gap < bestGap - 1 || (gap < bestGap + 1 && dx < bestDx)) {
        best = candidate;
        bestGap = gap;
        bestDx = dx;
      }
    }
    return alignedOnly ? bestAligned : (bestAligned ?? best);
  }

  @override
  Widget build(BuildContext context) {
    if (!FormFactorInfo.isAndroidTv) return widget.child;
    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: _onVerticalKey,
        child: widget.child,
      ),
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

/// Gives Android TV a desktop-sized logical canvas.
///
/// TV panels report ~320 dpi, so a 1080p screen hands Flutter only
/// 960x540 logical pixels — the app's layouts were designed around
/// ~1280+, so on TV everything renders oversized and grids lose columns
/// ("tout est un peu gros", confirmed by the diag strip's `960x540@2.0`).
///
/// This re-declares the canvas at [targetWidth] logical pixels and scales
/// the whole tree down to fit, exactly like running the app in a wider
/// window. Text, paddings and tile counts all fall back into their
/// intended proportions; nothing in the app has to know about it.
/// No-op off Android TV, and off when the panel is already wide enough.
/// Global kill-switch for [TvUiScale].
///
/// Screens hosting a native PlatformView — the libVLC player — turn this
/// off while they are visible. A PlatformView composited under a
/// FittedBox/Transform is a known source of trouble on Android (the
/// native surface is not part of the Flutter layer being scaled), and on
/// the test TV it coincided with stuttering video and crashes when
/// leaving playback. Video is full-screen anyway, so it has nothing to
/// gain from the scaled canvas.
final ValueNotifier<bool> tvUiScaleEnabled = ValueNotifier<bool>(true);

class TvUiScale extends StatelessWidget {
  const TvUiScale({super.key, required this.child, this.targetWidth = 1280});

  final Widget child;
  final double targetWidth;

  @override
  Widget build(BuildContext context) {
    if (!FormFactorInfo.isAndroidTv) return child;
    return ValueListenableBuilder<bool>(
      valueListenable: tvUiScaleEnabled,
      builder: (context, enabled, _) =>
          enabled ? _scaled(context) : child,
    );
  }

  Widget _scaled(BuildContext context) {
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    if (w <= 0 || w >= targetWidth) return child;
    final scale = w / targetWidth;
    final logical = Size(targetWidth, mq.size.height / scale);
    return MediaQuery(
      // Report the enlarged canvas so layout code (and MediaQuery-driven
      // breakpoints) reason in the scaled space, and compensate the
      // device pixel ratio so image decode sizes stay physically correct.
      data: mq.copyWith(
        size: logical,
        devicePixelRatio: mq.devicePixelRatio * scale,
        padding: EdgeInsets.zero,
        viewPadding: EdgeInsets.zero,
        viewInsets: EdgeInsets.zero,
      ),
      child: FittedBox(
        fit: BoxFit.fill,
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: logical.width,
          height: logical.height,
          child: child,
        ),
      ),
    );
  }
}
