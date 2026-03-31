import 'package:flutter/material.dart';
import 'package:unistream/core/colors.dart';

class SkeletonList extends StatefulWidget {
  final int  count;
  final bool isGrid;
  const SkeletonList({super.key, this.count = 10, this.isGrid = false});
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

  Widget _tile(Color color, {double? height, double? aspectRatio}) => Container(
    margin: const EdgeInsets.all(4),
    height: height,
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: color),
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) {
      final c = Color.lerp(AppColors.darkText, AppColors.darkTextShimmer, _anim.value)!;
      if (widget.isGrid) {
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.58),
          itemCount: widget.count,
          itemBuilder: (_, __) => _tile(c),
        );
      }
      return ListView.builder(
        itemCount: widget.count,
        itemBuilder: (_, __) => _tile(c, height: 36),
      );
    },
  );
}
