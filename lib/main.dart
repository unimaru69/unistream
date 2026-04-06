import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'package:sentry_flutter/sentry_flutter.dart';
import 'core/logger.dart';
import 'l10n/app_localizations.dart';
import 'core/colors.dart';
import 'core/sentry_config.dart';
import 'core/storage_keys.dart';
import 'providers/locale_provider.dart';
import 'models/app_config.dart';
import 'providers/favorites_provider.dart';
import 'providers/collections_provider.dart';
import 'providers/watch_progress_provider.dart';
import 'services/supabase_config.dart';
import 'services/epg_reminder_service.dart';
import 'services/sync_service.dart';
import 'services/watch_progress.dart';
import 'utils/routes.dart';
import 'utils/theme.dart';
import 'screens/splash_screen.dart';
import 'screens/player/player_screen.dart';

// Re-export theme utilities for screens that need them
export 'utils/theme.dart' show themeNotifier, saveThemeMode;

// ── Mini Player State ──
class MiniPlayerState {
  final Player player;
  final VideoController controller;
  final String title;
  final String? coverUrl;
  final String? resumeKey;
  final String url;

  Timer? _saveTimer;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;
  Duration _lastPos = Duration.zero;
  Duration _lastDur = Duration.zero;
  bool _disposed = false;

  MiniPlayerState({
    required this.player,
    required this.controller,
    required this.title,
    this.coverUrl,
    this.resumeKey,
    required this.url,
  });

  bool get isDisposed => _disposed;

  void startTracking() {
    if (resumeKey == null || _disposed) return;
    _posSub = player.stream.position.listen((p) => _lastPos = p);
    _durSub = player.stream.duration.listen((d) => _lastDur = d);
    _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_disposed) return;
      if (_lastDur > Duration.zero) WatchProgress.save(resumeKey!, _lastPos, _lastDur);
    });
  }

  void stopTracking() {
    _saveTimer?.cancel();
    _saveTimer = null;
    _posSub?.cancel();
    _posSub = null;
    _durSub?.cancel();
    _durSub = null;
    if (resumeKey != null && _lastDur > Duration.zero) {
      WatchProgress.save(resumeKey!, _lastPos, _lastDur);
    }
  }

  void close() {
    if (_disposed) return;
    stopTracking();
    player.dispose();
    _disposed = true;
  }
}

final ValueNotifier<MiniPlayerState?> miniPlayerNotifier = ValueNotifier(null);

// Global Navigator key for overlay insertion
final navKey = GlobalKey<NavigatorState>();
OverlayEntry? miniEntry;

void showMiniOverlay(MiniPlayerState state) {
  miniEntry?.remove();
  miniEntry = OverlayEntry(builder: (_) => _MiniPlayerWidget(
    state: state,
    onRestore: () {
      miniEntry?.remove();
      miniEntry = null;
      state.stopTracking();
      navKey.currentState?.push(slideRoute(PlayerScreen(
        url: state.url,
        title: state.title,
        resumeKey: state.resumeKey,
        coverUrl: state.coverUrl,
        existingPlayer: state.player,
        existingController: state.controller,
      )));
    },
    onClose: () {
      miniEntry?.remove();
      miniEntry = null;
      miniPlayerNotifier.value = null;
      state.close();
    },
  ));
  navKey.currentState?.overlay?.insert(miniEntry!);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await SupabaseConfig.initialize();
  await AppConfig.load();

  // Window size/position persistence (macOS/Windows/Linux)
  if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
    await windowManager.ensureInitialized();
    final prefs = await SharedPreferences.getInstance();
    final w = prefs.getDouble(StorageKeys.windowW) ?? 1280;
    final h = prefs.getDouble(StorageKeys.windowH) ?? 800;
    final x = prefs.getDouble(StorageKeys.windowX);
    final y = prefs.getDouble(StorageKeys.windowY);
    final windowOptions = WindowOptions(
      size: Size(w, h),
      minimumSize: const Size(800, 500),
      center: x == null,
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      if (x != null && y != null) {
        await windowManager.setPosition(Offset(x, y));
      }
      await windowManager.show();
      await windowManager.focus();
    });
  }

  await loadThemeMode();

  // Global async error handler (catches errors outside of Flutter framework)
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.error(LogModule.ui, 'Unhandled async error', error: error, stackTrace: stack);
    return true;
  };

  if (isSentryEnabled) {
    await SentryFlutter.init(
      (options) {
        options.dsn = sentryDsn;
        options.tracesSampleRate = 0.2;
        options.sendDefaultPii = false;
      },
      appRunner: () => runApp(const ProviderScope(child: UniStreamApp())),
    );
  } else {
    // In non-Sentry mode, still capture Flutter framework errors via AppLogger
    FlutterError.onError = (details) {
      AppLogger.error(LogModule.ui, 'Flutter framework error',
          error: details.exception, stackTrace: details.stack);
    };
    runApp(const ProviderScope(child: UniStreamApp()));
  }
}

class UniStreamApp extends ConsumerStatefulWidget {
  const UniStreamApp({super.key});
  @override
  ConsumerState<UniStreamApp> createState() => _UniStreamAppState();
}

class _UniStreamAppState extends ConsumerState<UniStreamApp> with WindowListener {
  Timer? _windowSaveTimer;

  @override
  void initState() {
    super.initState();
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      windowManager.addListener(this);
    }
    // Init EPG reminder service
    EpgReminderService.instance.init(onAlert: _onEpgReminderAlert);
    // Pull remote data and start realtime after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _initSync());
  }

  /// Pull remote data from Supabase and merge into local providers,
  /// then start realtime subscriptions for live cross-device sync.
  Future<void> _initSync() async {
    try {
      final sync = SyncService.instance;
      final remote = await sync.pullAll();

      // Merge into providers (fire-and-forget, errors swallowed per-provider)
      await Future.wait([
        ref.read(favoritesProvider.notifier).mergeFromRemote(remote.favorites),
        ref.read(watchlistProvider.notifier).mergeFromRemote(remote.watchlist),
        ref.read(collectionsProvider.notifier).mergeFromRemote(remote.collections),
        WatchProgress.mergeFromRemote(remote.watchProgress).then((changed) {
          if (changed) ref.invalidate(watchProgressProvider);
        }),
      ]);

      AppLogger.info(LogModule.sync, 'Startup sync pull complete');

      // Start realtime subscriptions for live sync
      sync.startRealtime((table) async {
        AppLogger.debug(LogModule.sync, 'Realtime change: $table');
        switch (table) {
          case 'user_favorites':
            final favs = await sync.pullFavorites('favorite');
            ref.read(favoritesProvider.notifier).mergeFromRemote(favs);
            final wl = await sync.pullFavorites('watchlist');
            ref.read(watchlistProvider.notifier).mergeFromRemote(wl);
          case 'user_collections':
            final cols = await sync.pullCollections();
            ref.read(collectionsProvider.notifier).mergeFromRemote(cols);
          case 'user_watch_progress':
            final wp = await sync.pullWatchProgress();
            final changed = await WatchProgress.mergeFromRemote(wp);
            if (changed) ref.invalidate(watchProgressProvider);
        }
      });
    } catch (e, st) {
      AppLogger.warning(LogModule.sync, 'Startup sync failed (offline?)',
          error: e, stackTrace: st);
    }
  }

  void _onEpgReminderAlert(EpgReminder reminder) {
    final ctx = navKey.currentContext;
    if (ctx == null) return;
    final l10n = AppLocalizations.of(ctx);
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text(l10n?.rappelProgramme(reminder.programTitle, reminder.channelName)
          ?? '${reminder.programTitle} starts soon on ${reminder.channelName}'),
      duration: const Duration(seconds: 8),
      action: SnackBarAction(
        label: 'OK',
        onPressed: () {},
      ),
    ));
  }

  @override
  void dispose() {
    _windowSaveTimer?.cancel();
    EpgReminderService.instance.dispose();
    SyncService.instance.stopRealtime();
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  void _debounceSaveWindowBounds() {
    _windowSaveTimer?.cancel();
    _windowSaveTimer = Timer(const Duration(milliseconds: 500), () async {
      final bounds = await windowManager.getBounds();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(StorageKeys.windowX, bounds.left);
      await prefs.setDouble(StorageKeys.windowY, bounds.top);
      await prefs.setDouble(StorageKeys.windowW, bounds.width);
      await prefs.setDouble(StorageKeys.windowH, bounds.height);
    });
  }

  @override
  void onWindowResized() => _debounceSaveWindowBounds();

  @override
  void onWindowMoved() => _debounceSaveWindowBounds();

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) => MaterialApp(
        title: 'UniStream',
        debugShowCheckedModeBanner: false,
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: mode,
        navigatorKey: navKey,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const SplashScreen(),
      ),
    );
  }
}

// ── Mini Player Widget ──
class _MiniPlayerWidget extends StatefulWidget {
  final MiniPlayerState state;
  final VoidCallback onRestore;
  final VoidCallback onClose;
  const _MiniPlayerWidget({required this.state, required this.onRestore, required this.onClose});
  @override
  State<_MiniPlayerWidget> createState() => _MiniPlayerWidgetState();
}

class _MiniPlayerWidgetState extends State<_MiniPlayerWidget>
    with TickerProviderStateMixin {
  Offset? _offset;
  double _width = 320;
  double _height = 190;
  static const double _minW = 200, _minH = 120, _maxW = 480, _maxH = 300;
  static const double _edgeMargin = 16;
  /// Distance threshold to trigger swipe-dismiss.
  static const double _dismissThreshold = 100;
  /// Velocity threshold to trigger swipe-dismiss (fast flick).
  static const double _dismissVelocity = 800;

  late AnimationController _snapController;
  Animation<Offset>? _snapAnimation;

  // Dismiss animation
  late AnimationController _dismissController;
  Animation<Offset>? _dismissAnimation;
  Animation<double>? _dismissOpacity;
  double _opacity = 1.0;

  // Volume gesture state
  bool _volumeDragging = false;
  double _volumeAtDragStart = 1.0;
  double _volumeOsdValue = -1; // -1 = hidden
  Timer? _volumeOsdTimer;

  // Drag tracking for dismiss detection
  Offset _dragStartOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
    _snapController.addListener(() {
      if (_snapAnimation != null) {
        setState(() => _offset = _snapAnimation!.value);
      }
    });
    _dismissController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _dismissController.addListener(() {
      if (_dismissAnimation != null && _dismissOpacity != null) {
        setState(() {
          _offset = _dismissAnimation!.value;
          _opacity = _dismissOpacity!.value;
        });
      }
    });
    _dismissController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onClose();
      }
    });
  }

  @override
  void dispose() {
    _snapController.dispose();
    _dismissController.dispose();
    _volumeOsdTimer?.cancel();
    super.dispose();
  }

  void _snapToEdge() {
    final size = MediaQuery.of(context).size;
    final current = _offset!;
    final centerX = current.dx + _width / 2;
    final centerY = current.dy + _height / 2;
    final targetX = centerX < size.width / 2
        ? _edgeMargin
        : size.width - _width - _edgeMargin;
    final targetY = centerY < size.height / 2
        ? _edgeMargin
        : size.height - _height - _edgeMargin;
    _snapAnimation = Tween<Offset>(
      begin: current,
      end: Offset(targetX, targetY),
    ).animate(CurvedAnimation(parent: _snapController, curve: Curves.easeOut));
    _snapController.forward(from: 0);
  }

  /// Animate off-screen in the given direction and close.
  void _animateDismiss(Offset velocity) {
    final size = MediaQuery.of(context).size;
    final current = _offset!;
    // Determine dismiss target based on velocity or position
    double targetX = current.dx;
    double targetY = current.dy;
    if (velocity.dy.abs() > velocity.dx.abs()) {
      // Vertical dismiss
      targetY = velocity.dy > 0 ? size.height + 50 : -_height - 50;
    } else {
      // Horizontal dismiss
      targetX = velocity.dx > 0 ? size.width + 50 : -_width - 50;
    }
    _dismissAnimation = Tween<Offset>(
      begin: current,
      end: Offset(targetX, targetY),
    ).animate(CurvedAnimation(parent: _dismissController, curve: Curves.easeIn));
    _dismissOpacity = Tween<double>(begin: _opacity, end: 0.0)
        .animate(CurvedAnimation(parent: _dismissController, curve: Curves.easeIn));
    _dismissController.forward(from: 0);
  }

  void _onPanStart(DragStartDetails d) {
    _dragStartOffset = _offset ?? Offset.zero;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    setState(() {
      _offset = _offset! + d.delta;
      // Fade out as user drags away from original position
      final dist = (_offset! - _dragStartOffset).distance;
      _opacity = (1.0 - (dist / (_dismissThreshold * 2))).clamp(0.3, 1.0);
    });
  }

  void _onPanEnd(DragEndDetails d) {
    final velocity = d.velocity.pixelsPerSecond;
    final dist = (_offset! - _dragStartOffset).distance;
    // Check if fast flick or dragged far enough
    if (velocity.distance > _dismissVelocity || dist > _dismissThreshold) {
      // Determine direction from velocity if fast enough, otherwise from offset delta
      final dir = velocity.distance > _dismissVelocity
          ? velocity
          : Offset(_offset!.dx - _dragStartOffset.dx, _offset!.dy - _dragStartOffset.dy);
      _animateDismiss(dir);
    } else {
      // Snap back
      setState(() => _opacity = 1.0);
      _snapToEdge();
    }
  }

  void _onVolumeVerticalDrag(DragStartDetails d) {
    _volumeDragging = true;
    _volumeAtDragStart = widget.state.player.state.volume / 100.0;
  }

  void _onVolumeVerticalUpdate(DragUpdateDetails d) {
    if (!_volumeDragging) return;
    // Dragging up = louder, down = quieter
    final delta = -d.delta.dy / _height;
    final newVol = (_volumeAtDragStart + delta).clamp(0.0, 1.0);
    _volumeAtDragStart = newVol;
    widget.state.player.setVolume(newVol * 100);
    setState(() => _volumeOsdValue = newVol);
    _volumeOsdTimer?.cancel();
    _volumeOsdTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _volumeOsdValue = -1);
    });
  }

  void _onVolumeVerticalEnd(DragEndDetails d) {
    _volumeDragging = false;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    _offset ??= Offset(size.width - _width - _edgeMargin, size.height - _height - _edgeMargin);
    final dx = _offset!.dx.clamp(-_width * 0.5, size.width  - _width * 0.5);
    final dy = _offset!.dy.clamp(-_height * 0.5, size.height - _height * 0.5);

    return Positioned(
      left: dx, top: dy,
      child: Opacity(
        opacity: _opacity,
        child: GestureDetector(
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          onDoubleTap: widget.onRestore,
          child: Material(
            elevation: 16,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            color: AppColors.darkSurface,
            child: SizedBox(
              width: _width, height: _height,
              child: Stack(fit: StackFit.expand, children: [
                Video(controller: widget.state.controller, controls: NoVideoControls),
                // Title gradient (top)
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Colors.black87, Colors.transparent]),
                    ),
                    child: Text(widget.state.title,
                        style: const TextStyle(color: Colors.white, fontSize: 11,
                            fontWeight: FontWeight.bold),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
                // Progress bar (thin, at the very bottom)
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: StreamBuilder<Duration>(
                    stream: widget.state.player.stream.position,
                    builder: (_, posSnap) {
                      final pos = posSnap.data ?? Duration.zero;
                      return StreamBuilder<Duration>(
                        stream: widget.state.player.stream.duration,
                        builder: (_, durSnap) {
                          final dur = durSnap.data ?? Duration.zero;
                          final ratio = dur.inMilliseconds > 0
                              ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
                              : 0.0;
                          if (ratio == 0.0) return const SizedBox.shrink();
                          return LinearProgressIndicator(
                            value: ratio,
                            backgroundColor: Colors.black45,
                            color: AppColors.primaryBlue,
                            minHeight: 3,
                          );
                        },
                      );
                    },
                  ),
                ),
                // Controls gradient (bottom)
                Positioned(
                  bottom: 3, left: 0, right: 0,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter, end: Alignment.topCenter,
                        colors: [Colors.black87, Colors.transparent]),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      StreamBuilder<bool>(
                        stream: widget.state.player.stream.playing,
                        builder: (_, snap) => IconButton(
                          icon: Icon(snap.data == true ? Icons.pause : Icons.play_arrow,
                              color: Colors.white, size: 24),
                          onPressed: () => widget.state.player.playOrPause(),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.open_in_full, color: Colors.white70, size: 18),
                        onPressed: widget.onRestore,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                        onPressed: widget.onClose,
                      ),
                    ]),
                  ),
                ),
                // Drag indicator (top-right)
                const Positioned(top: 6, right: 6,
                    child: Icon(Icons.drag_indicator, color: Colors.white30, size: 14)),
                // Volume gesture zone (right edge strip)
                Positioned(
                  top: 30, right: 0, bottom: 40,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onVerticalDragStart: _onVolumeVerticalDrag,
                    onVerticalDragUpdate: _onVolumeVerticalUpdate,
                    onVerticalDragEnd: _onVolumeVerticalEnd,
                    child: SizedBox(width: 30, child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.volume_up, color: Colors.white.withValues(alpha: 0.3), size: 12),
                      ],
                    )),
                  ),
                ),
                // Volume OSD
                if (_volumeOsdValue >= 0)
                  Positioned(
                    top: 30, right: 6, bottom: 40,
                    child: Container(
                      width: 4,
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: _volumeOsdValue.clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Resize handle (bottom-right)
                Positioned(
                  bottom: 0, right: 0,
                  child: GestureDetector(
                    onPanUpdate: (d) {
                      setState(() {
                        _width  = (_width  + d.delta.dx).clamp(_minW, _maxW);
                        _height = (_height + d.delta.dy).clamp(_minH, _maxH);
                      });
                    },
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeDownRight,
                      child: Container(
                        width: 20, height: 20,
                        alignment: Alignment.bottomRight,
                        child: const Icon(Icons.drag_handle, color: Colors.white30, size: 12),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
