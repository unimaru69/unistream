import 'dart:async';
import 'dart:io';

import 'package:media_kit/media_kit.dart';

/// Instrumentation for the "playback pauses for a second, every second
/// or two" report on Linux (Fedora, release AppImage).
///
/// Three unrelated mpv-level mechanisms all look identical from the Dart
/// side — the picture and the sound stop together, then resume — so the
/// only way to tell them apart is to ask mpv for its own counters:
///
/// * **the demuxer cache runs dry** — the stream arrives slower than it
///   plays, or (media_kit sets `cache-on-disk=yes` on every platform)
///   the cache file's writes stall the demuxer thread on a slow disk.
///   Fingerprint: `for-cache=yes` with `cache` collapsing towards 0 and
///   a low `speed`.
/// * **the CPU cannot decode in real time** — Linux runs `hwdec=no` on
///   purpose (host VA-API/VDPAU drivers are a lottery). Fingerprint:
///   `dec-drop` climbing every second while `cache` stays healthy.
/// * **the frames cannot reach the screen** — media_kit_video falls
///   back to software rendering whenever it fails to get an isolated
///   EGL context, and that path copies every frame through a 1080p RGBA
///   buffer on the CPU. Fingerprint: `vo-delay` climbing and `vf-fps`
///   far below `fps`. The plugin also names the path it picked at
///   startup: look for `media_kit: VideoOutput:` on stderr.
///
/// Enabled only when `UNISTREAM_PLAYER_DIAG=1` is in the environment.
/// It writes straight to stderr rather than through [AppLogger] because
/// `package:logger` drops everything in release builds and the
/// reproduction only happens on a release AppImage.
class PlayerStallDiagnostics {
  static bool get enabled =>
      Platform.environment['UNISTREAM_PLAYER_DIAG'] == '1';

  NativePlayer? _np;
  Timer? _timer;
  StreamSubscription<bool>? _bufferingSubscription;
  final Stopwatch _clock = Stopwatch();

  // Drop counters are cumulative; only their per-second delta says
  // anything about what is happening right now.
  int _lastDecoderDrops = 0;
  int _lastOutputDrops = 0;
  int _lastDelayedFrames = 0;
  bool _headerPrinted = false;

  /// Starts sampling [player]. No-op unless [enabled].
  void attach(Player player) {
    if (!enabled) return;
    final platform = player.platform;
    if (platform is! NativePlayer) return;
    _np = platform;
    _clock.start();
    _write('diag enabled (UNISTREAM_PLAYER_DIAG=1) — sampling every 1s');
    _bufferingSubscription = player.stream.buffering.listen((buffering) {
      _write(buffering ? 'BUFFERING start' : 'BUFFERING end');
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _sample());
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _bufferingSubscription?.cancel();
    _bufferingSubscription = null;
    _np = null;
  }

  Future<void> _sample() async {
    final np = _np;
    if (np == null) return;
    try {
      if (!_headerPrinted) {
        final width = await np.getProperty('video-params/w');
        // Nothing decoded yet — wait for the first frame so the static
        // header carries real codec/resolution values.
        if ((int.tryParse(width) ?? 0) == 0) return;
        _headerPrinted = true;
        final height = await np.getProperty('video-params/h');
        _write('stream  codec=${await np.getProperty('video-codec')}'
            ' ${width}x$height'
            ' fps=${await np.getProperty('container-fps')}'
            ' pixfmt=${await np.getProperty('video-params/pixelformat')}');
        _write('pipeline hwdec=${await np.getProperty('hwdec-current')}'
            ' vo=${await np.getProperty('current-vo')}'
            ' ao=${await np.getProperty('current-ao')}'
            ' cache-on-disk=${await np.getProperty('cache-on-disk')}'
            ' demuxer-max-bytes=${await np.getProperty('demuxer-max-bytes')}'
            ' cache-secs=${await np.getProperty('cache-secs')}');
      }

      final forCache = await np.getProperty('paused-for-cache');
      final cacheSecs = double.tryParse(
              await np.getProperty('demuxer-cache-duration')) ??
          -1;
      final cacheSpeed = double.tryParse(await np.getProperty('cache-speed')) ?? 0;
      final bitrate = double.tryParse(await np.getProperty('video-bitrate')) ?? 0;
      final decoderDrops =
          int.tryParse(await np.getProperty('decoder-frame-drop-count')) ?? 0;
      final outputDrops =
          int.tryParse(await np.getProperty('frame-drop-count')) ?? 0;
      final delayedFrames =
          int.tryParse(await np.getProperty('vo-delayed-frame-count')) ?? 0;
      final vfFps = await np.getProperty('estimated-vf-fps');
      final avsync = await np.getProperty('avsync');

      final decoderDelta = decoderDrops - _lastDecoderDrops;
      final outputDelta = outputDrops - _lastOutputDrops;
      final delayedDelta = delayedFrames - _lastDelayedFrames;
      _lastDecoderDrops = decoderDrops;
      _lastOutputDrops = outputDrops;
      _lastDelayedFrames = delayedFrames;

      _write('for-cache=$forCache'
          ' cache=${cacheSecs.toStringAsFixed(1)}s'
          ' speed=${_mbps(cacheSpeed * 8)}'
          ' bitrate=${_mbps(bitrate)}'
          ' dec-drop=+$decoderDelta'
          ' vo-drop=+$outputDelta'
          ' vo-delay=+$delayedDelta'
          ' vf-fps=$vfFps'
          ' avsync=$avsync');
    } catch (_) {
      // The player was disposed between the timer tick and the read.
      dispose();
    }
  }

  static String _mbps(double bitsPerSecond) =>
      '${(bitsPerSecond / 1000000).toStringAsFixed(1)}Mb/s';

  void _write(String line) {
    final t = (_clock.elapsedMilliseconds / 1000).toStringAsFixed(1);
    try {
      stderr.writeln('[player-diag ${t}s] $line');
    } catch (_) {
      // stderr is not always writable (detached launcher); never fatal.
    }
  }
}
