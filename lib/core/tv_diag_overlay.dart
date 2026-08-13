import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show FlutterExceptionHandler;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'form_factor.dart';

/// Build with `--dart-define=TVDIAG=true` to enable the on-screen
/// diagnostic strip on Android TV builds.
const bool kTvDiag = bool.fromEnvironment('TVDIAG', defaultValue: false);

/// Tiny always-on-top diagnostic strip for TV field debugging.
///
/// The Philips test TV has no working adb and silent kills leave nothing
/// in Sentry — the only "telemetry" channel left is the TV panel itself:
/// the user photographs the strip right before the app dies.
///
/// Reading the photo:
/// - `f` (frames painted) frozen while the clock advances → the raster /
///   UI thread is wedged (GPU driver hang, main-isolate freeze);
/// - `f` ticking until death → the UI was alive; the kill came from
///   outside (low-memory killer) — check `rss`;
/// - `err` non-empty → a Dart exception fired; the text names it.
class TvDiagOverlay extends StatefulWidget {
  const TvDiagOverlay({super.key});

  @override
  State<TvDiagOverlay> createState() => _TvDiagOverlayState();
}

class _TvDiagOverlayState extends State<TvDiagOverlay> {
  final Stopwatch _uptime = Stopwatch()..start();
  Timer? _refresh;
  int _frames = 0;
  String _lastError = '';
  FlutterExceptionHandler? _prevOnError;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPersistentFrameCallback((_) => _frames++);
    // Chain (don't replace) the existing handler so Sentry still reports.
    _prevOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      _lastError = details.exceptionAsString();
      _prevOnError?.call(details);
    };
    _refresh = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _refresh?.cancel();
    FlutterError.onError = _prevOnError;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rssMb = (ProcessInfo.currentRss / (1 << 20)).round();
    final up = _uptime.elapsed;
    final text = 'DIAG ${up.inSeconds}s  f=$_frames  rss=${rssMb}M'
        '${_lastError.isEmpty ? '' : '  err=${_lastError.substring(0, _lastError.length > 60 ? 60 : _lastError.length)}'}';
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topLeft,
        child: Container(
          margin: const EdgeInsets.only(top: 2, left: 2),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          color: const Color(0xB3000000),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'monospace',
              // Red when an error was caught — visible on a photo.
              color: _lastError.isEmpty
                  ? const Color(0xFF7CFC00)
                  : const Color(0xFFFF5252),
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}

/// Wraps [child] with the diag strip when enabled (TV + TVDIAG define).
Widget withTvDiagOverlay(Widget child) {
  if (!kTvDiag || !FormFactorInfo.isAndroidTv) return child;
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Stack(children: [child, const TvDiagOverlay()]),
  );
}
