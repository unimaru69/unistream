import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_vlc_player/src/vlc_player_controller.dart';
import 'package:flutter_vlc_player/src/vlc_player_platform.dart';

// ignore: prefer_match_file_name
class VlcPlayer extends StatefulWidget {
  final VlcPlayerController controller;
  final double aspectRatio;
  final Widget? placeholder;
  final bool virtualDisplay;

  const VlcPlayer({
    /// The [VlcPlayerController] responsible for the video being rendered in
    /// this widget.
    required this.controller,

    /// The aspect ratio used to display the video.
    /// This MUST be provided, however it could simply be (parentWidth / parentHeight) - where parentWidth and
    /// parentHeight are the width and height of the parent perhaps as defined by a LayoutBuilder.
    required this.aspectRatio,

    /// Before the platform view has initialized, this placeholder will be rendered instead of the video player.
    /// This can simply be a [CircularProgressIndicator] (see the example.)
    this.placeholder,

    /// Specify whether Virtual displays or Hybrid composition is used on Android.
    /// iOS only uses Hybrid composition.
    this.virtualDisplay = true,
    super.key,
  });

  @override
  _VlcPlayerState createState() => _VlcPlayerState();
}

class _VlcPlayerState extends State<VlcPlayer> {
  bool _isInitialized = false;

  /// Android only. libVLC draws into a SurfaceTexture registered with
  /// Flutter, but upstream only ever shows the platform view — on some
  /// devices nothing presents those frames and the picture stays black
  /// while audio plays. With the id we can draw that texture directly.
  int? _textureId;

  //ignore: avoid_late_keyword
  late VoidCallback _listener;

  _VlcPlayerState() {
    _listener = () {
      if (!mounted) return;
      //
      final isInitialized = widget.controller.value.isInitialized;
      if (isInitialized != _isInitialized) {
        setState(() {
          _isInitialized = isInitialized;
        });
      }
    };
  }

  @override
  void initState() {
    super.initState();
    _isInitialized = widget.controller.value.isInitialized;
    // Need to listen for initialization events since the actual initialization value
    // becomes available after asynchronous initialization finishes.
    widget.controller.addListener(_listener);
  }

  /// Forwards to the controller, then asks the Android side for the id of
  /// the texture libVLC renders into. Failure is non-fatal: without it the
  /// widget behaves exactly as upstream.
  Future<void> _onPlatformViewCreated(int id) async {
    widget.controller.onPlatformViewCreated(id);
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final textureId = await MethodChannel(
        'flutter_video_plugin/getTextureId_$id',
      ).invokeMethod<int>('getTextureId');
      if (mounted && textureId != null) {
        setState(() => _textureId = textureId);
      }
    } catch (_) {
      // Older/other implementations don't answer — keep the platform view.
    }
  }

  @override
  Widget build(BuildContext context) {
    // Read the controller directly instead of trusting the cached flag.
    //
    // Upstream keeps `_isInitialized` in a field fed by a listener, and
    // hides the whole player subtree behind an Offstage while it is false.
    // If the controller finishes initializing before that listener is
    // attached, the flag never changes again — nothing ever notifies a
    // value that is already set — and the player is built but never
    // painted. That is exactly what happened on the Skyworth/Amlogic TV
    // box, where VLC goes initialized → buffering → playing in ~65 ms:
    // audio played, the picture stayed black, and so did a debug frame
    // drawn inside the subtree.
    final initialized =
        _isInitialized || widget.controller.value.isInitialized;
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Always mounted and painted: creating the platform view is what
          // instantiates the native player, and its layout drives VLC's
          // window size.
          vlcPlayerPlatform.buildView(
            _onPlatformViewCreated,
            virtualDisplay: widget.virtualDisplay,
          ),
          if (_textureId != null) Texture(textureId: _textureId!),
          // Placeholder covers the player while it connects, rather than
          // the player being hidden — no flag can strand it now.
          if (!initialized) widget.placeholder ?? Container(),
        ],
      ),
    );
  }

  @override
  void didUpdateWidget(VlcPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_listener);
      _isInitialized = widget.controller.value.isInitialized;
      widget.controller.addListener(_listener);
    }
  }

  @override
  void deactivate() {
    super.deactivate();
    widget.controller.removeListener(_listener);
  }
}
