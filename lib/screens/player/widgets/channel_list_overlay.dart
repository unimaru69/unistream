import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:unistream/core/colors.dart';
import 'package:unistream/l10n/app_localizations.dart';
import '../../../models/channel.dart';

/// Full-screen overlay listing all channels for quick selection.
/// Triggered by 'L' key during live playback.
class ChannelListOverlay extends StatefulWidget {
  final List<Channel> channels;
  final int currentIndex;
  final void Function(int index) onSelect;
  final VoidCallback onClose;

  const ChannelListOverlay({
    super.key,
    required this.channels,
    required this.currentIndex,
    required this.onSelect,
    required this.onClose,
  });

  @override
  State<ChannelListOverlay> createState() => _ChannelListOverlayState();
}

class _ChannelListOverlayState extends State<ChannelListOverlay>
    with SingleTickerProviderStateMixin {
  late final ScrollController _scrollController;
  late final AnimationController _anim;
  late final FocusNode _focusNode;
  int _highlightedIndex = 0;

  @override
  void initState() {
    super.initState();
    _highlightedIndex = widget.currentIndex;
    _scrollController = ScrollController(
      initialScrollOffset: (widget.currentIndex * 48.0 - 120).clamp(0, double.infinity),
    );
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..forward();
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _anim.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.keyL) {
      widget.onClose();
      return;
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.select) {
      widget.onSelect(_highlightedIndex);
      return;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _moveHighlight(-1);
      return;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _moveHighlight(1);
      return;
    }
  }

  void _moveHighlight(int delta) {
    final newIdx = (_highlightedIndex + delta).clamp(0, widget.channels.length - 1);
    if (newIdx == _highlightedIndex) return;
    setState(() => _highlightedIndex = newIdx);
    // Ensure the highlighted item is visible
    final offset = (newIdx * 48.0 - 120).clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(offset,
        duration: const Duration(milliseconds: 100), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return FadeTransition(
      opacity: _anim,
      child: KeyboardListener(
        focusNode: _focusNode,
        onKeyEvent: _handleKey,
        child: GestureDetector(
          onTap: widget.onClose,
          child: Container(
            color: Colors.black.withValues(alpha: 0.7),
            child: Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: () {}, // prevent close when tapping the list
                child: Container(
                  width: 320,
                  margin: const EdgeInsets.symmetric(vertical: 32),
                  decoration: BoxDecoration(
                    color: AppColors.darkSurface,
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(12),
                    ),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Row(
                          children: [
                            const Icon(Icons.live_tv, size: 18, color: Colors.white70),
                            const SizedBox(width: 8),
                            Text(
                              loc.live,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              loc.nombreChaines(widget.channels.length),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white38,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Colors.white12),
                      Expanded(
                        child: ListView.builder(
                          controller: _scrollController,
                          itemCount: widget.channels.length,
                          itemExtent: 48,
                          itemBuilder: (_, i) {
                            final ch = widget.channels[i];
                            final name = ch.name.isNotEmpty ? ch.name : loc.sansTitre;
                            final num = ch.num?.toString() ?? '';
                            final isCurrent = i == widget.currentIndex;
                            final isHighlighted = i == _highlightedIndex;

                            return Semantics(
                              button: true,
                              label: '${num.isNotEmpty ? '$num. ' : ''}$name${isCurrent ? ', en cours' : ''}',
                              child: Material(
                                color: isHighlighted
                                    ? AppColors.primaryBlue.withValues(alpha: 0.3)
                                    : isCurrent
                                        ? AppColors.primaryBlue.withValues(alpha: 0.12)
                                        : Colors.transparent,
                                child: InkWell(
                                  onTap: () => widget.onSelect(i),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Row(
                                      children: [
                                        if (num.isNotEmpty)
                                          SizedBox(
                                            width: 36,
                                            child: ExcludeSemantics(child: Text(
                                              num,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isCurrent
                                                    ? AppColors.primaryBlue
                                                    : Colors.white38,
                                                fontWeight: isCurrent
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                              ),
                                            )),
                                          ),
                                        Expanded(
                                          child: ExcludeSemantics(child: Text(
                                            name,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: isCurrent
                                                  ? Colors.white
                                                  : Colors.white70,
                                              fontWeight: isCurrent
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          )),
                                        ),
                                        if (isCurrent)
                                          const ExcludeSemantics(child: Icon(Icons.play_arrow,
                                              size: 16, color: AppColors.primaryBlue)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
