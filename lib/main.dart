import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'dart:async';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'core/colors.dart';
import 'core/sentry_config.dart';
import 'core/storage_keys.dart';
import 'providers/locale_provider.dart';
import 'models/app_config.dart';
import 'services/watch_progress.dart';
import 'utils/routes.dart';
import 'utils/theme.dart';
import 'screens/home/home_screen.dart';
import 'screens/settings_screen.dart';
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

  MiniPlayerState({
    required this.player,
    required this.controller,
    required this.title,
    this.coverUrl,
    this.resumeKey,
    required this.url,
  });

  void startTracking() {
    if (resumeKey == null) return;
    _posSub = player.stream.position.listen((p) => _lastPos = p);
    _durSub = player.stream.duration.listen((d) => _lastDur = d);
    _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_lastDur > Duration.zero) WatchProgress.save(resumeKey!, _lastPos, _lastDur);
    });
  }

  void stopTracking() {
    _saveTimer?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    if (resumeKey != null && _lastDur > Duration.zero) {
      WatchProgress.save(resumeKey!, _lastPos, _lastDur);
    }
  }

  void close() {
    stopTracking();
    player.dispose();
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
  }

  @override
  void dispose() {
    _windowSaveTimer?.cancel();
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
        home: AppConfig.isConfigured
            ? const HomeScreen()
            : const SettingsScreen(isOnboarding: true),
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
    with SingleTickerProviderStateMixin {
  Offset? _offset;
  double _width = 320;
  double _height = 190;
  static const double _minW = 200, _minH = 120, _maxW = 480, _maxH = 300;
  static const double _edgeMargin = 16;

  late AnimationController _snapController;
  Animation<Offset>? _snapAnimation;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
    _snapController.addListener(() {
      if (_snapAnimation != null) {
        setState(() => _offset = _snapAnimation!.value);
      }
    });
  }

  @override
  void dispose() {
    _snapController.dispose();
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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    _offset ??= Offset(size.width - _width - _edgeMargin, size.height - _height - _edgeMargin);
    final dx = _offset!.dx.clamp(0.0, size.width  - _width);
    final dy = _offset!.dy.clamp(0.0, size.height - _height);

    return Positioned(
      left: dx, top: dy,
      child: GestureDetector(
        onPanUpdate: (d) => setState(() => _offset = _offset! + d.delta),
        onPanEnd: (_) => _snapToEdge(),
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
              Positioned(
                bottom: 0, left: 0, right: 0,
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
              const Positioned(top: 6, right: 6,
                  child: Icon(Icons.drag_indicator, color: Colors.white30, size: 14)),
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
    );
  }
}
