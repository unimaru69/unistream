import 'package:flutter/material.dart';
import 'package:unistream/core/theme_colors.dart';

class SkeletonList extends StatefulWidget {
  final int  count;
  final bool isGrid;
  /// When true, the inner ListView/GridView shrink-wraps its children
  /// instead of trying to fill an unbounded viewport. Required when the
  /// skeleton is hosted inside a `SliverToBoxAdapter` or any other
  /// parent that does not bound the cross-axis size.
  final bool shrinkWrap;
  const SkeletonList({
    super.key,
    this.count = 10,
    this.isGrid = false,
    this.shrinkWrap = false,
  });
  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList> with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }
  @override
  void dispose() { _anim.dispose(); super.dispose(); }

  Widget _tile(Color color, {double? height}) => Container(
    margin: const EdgeInsets.all(4),
    height: height,
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: color),
  );

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    return ExcludeSemantics(child: AnimatedBuilder(
    animation: _anim,
    builder: (_, __) {
      final c = Color.lerp(tc.shimmerBase, tc.shimmerHighlight, _anim.value)!;
      if (widget.isGrid) {
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          shrinkWrap: widget.shrinkWrap,
          physics: widget.shrinkWrap ? const NeverScrollableScrollPhysics() : null,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.58),
          itemCount: widget.count,
          itemBuilder: (_, __) => _tile(c),
        );
      }
      return ListView.builder(
        shrinkWrap: widget.shrinkWrap,
        physics: widget.shrinkWrap ? const NeverScrollableScrollPhysics() : null,
        itemCount: widget.count,
        itemBuilder: (_, __) => _tile(c, height: 36),
      );
    },
  ));
  }
}
