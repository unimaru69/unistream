import 'package:flutter/material.dart';

import '../../../core/colors.dart';
import '../../../core/design_tokens.dart';
import '../../../core/typography.dart';

/// Sort options shared by the VOD and Séries split views. Mirror of
/// `tvos/UniStreamTV/UniStreamTV/Views/Components/CatalogSortChips.swift`.
///
/// The "default" order is whatever the IPTV provider returns —
/// preserved for users with muscle memory on their catalogue.
enum CatalogSortMode {
  defaultOrder('default', 'Défaut', Icons.list),
  recent('recent', 'Récents', Icons.history),
  alphabetical('alpha', 'A-Z', Icons.sort_by_alpha),
  unwatched('unwatched', 'Non vus', Icons.radio_button_unchecked),
  inProgress('inProgress', 'En cours', Icons.play_circle_outline);

  const CatalogSortMode(this.id, this.label, this.icon);

  /// Stable string id — persisted in shared prefs, also written into
  /// the legacy `_sortMode` field on home_screen.
  final String id;
  final String label;
  final IconData icon;

  static CatalogSortMode fromId(String id) =>
      CatalogSortMode.values.firstWhere(
        (m) => m.id == id,
        orElse: () => CatalogSortMode.defaultOrder,
      );
}

/// Horizontal scroll of capsule chips for picking a catalogue sort
/// mode. Same chip language as the season picker on the Series
/// detail screen.
class CatalogSortChips extends StatelessWidget {
  const CatalogSortChips({
    super.key,
    required this.selection,
    required this.onChanged,
    this.modes = CatalogSortMode.values,
    this.padding,
  });

  final CatalogSortMode selection;
  final ValueChanged<CatalogSortMode> onChanged;
  final List<CatalogSortMode> modes;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding ??
            EdgeInsets.symmetric(horizontal: DS.padding.screenHorizontal),
        itemCount: modes.length,
        separatorBuilder: (_, __) => SizedBox(width: DS.space.sm),
        itemBuilder: (_, i) {
          final mode = modes[i];
          return _SortChip(
            mode: mode,
            selected: mode == selection,
            onTap: () => onChanged(mode),
          );
        },
      ),
    );
  }
}

class _SortChip extends StatefulWidget {
  const _SortChip({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final CatalogSortMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_SortChip> createState() => _SortChipState();
}

class _SortChipState extends State<_SortChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Color fill;
    final Color fg;
    if (_hovered) {
      fill = Colors.white;
      fg = Colors.black;
    } else if (widget.selected) {
      fill = AppColors.primaryBlue;
      fg = Colors.white;
    } else {
      fill = Colors.white.withValues(alpha: 0.10);
      fg = DS.colour.textSecondary;
    }

    final scale = _hovered ? DS.focus.chipScale : 1.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: scale,
          duration: DS.focus.animation,
          curve: DS.focus.curve,
          child: AnimatedContainer(
            duration: DS.focus.animation,
            curve: DS.focus.curve,
            padding: EdgeInsets.symmetric(
              horizontal: DS.space.lg,
              vertical: DS.space.xs,
            ),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(DS.radius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(widget.mode.icon, size: 14, color: fg),
                SizedBox(width: DS.space.xs),
                Text(
                  widget.mode.label,
                  style: DSText.bodyEmphasised.copyWith(color: fg),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
