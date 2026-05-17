import 'package:flutter/material.dart';

import '../../../core/colors.dart';
import '../../../core/design_tokens.dart';
import '../../../core/typography.dart';

/// Inline search trigger that mirrors
/// `tvos/UniStreamTV/UniStreamTV/Views/Components/InlineSearchField.swift`.
///
/// Idle: a capsule with magnifier icon + "Rechercher" placeholder.
/// Active (query non-empty): the same capsule fills accent teal and
/// shows `« query »` so the user knows the grid is filtered.
/// On tap: focuses an inline text field that expands inside the same
/// capsule (no modal sheet — desktop has plenty of room).
class InlineSearchField extends StatefulWidget {
  const InlineSearchField({
    super.key,
    required this.query,
    required this.onChanged,
    this.placeholder = 'Rechercher',
    this.maxWidth = 320,
  });

  final String query;
  final ValueChanged<String> onChanged;
  final String placeholder;
  final double maxWidth;

  @override
  State<InlineSearchField> createState() => _InlineSearchFieldState();
}

class _InlineSearchFieldState extends State<InlineSearchField> {
  bool _editing = false;
  bool _hovered = false;
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(InlineSearchField old) {
    super.didUpdateWidget(old);
    if (widget.query != _controller.text) {
      _controller.text = widget.query;
      _controller.selection =
          TextSelection.collapsed(offset: _controller.text.length);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus && widget.query.isEmpty) {
      setState(() => _editing = false);
    }
  }

  void _startEditing() {
    setState(() => _editing = true);
    Future<void>.microtask(() {
      if (!mounted) return;
      _focusNode.requestFocus();
    });
  }

  void _clear() {
    _controller.clear();
    widget.onChanged('');
    setState(() => _editing = false);
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.query.isNotEmpty;
    final Color fill;
    final Color fg;
    if (_hovered && !_editing) {
      fill = Colors.white;
      fg = Colors.black;
    } else if (_editing) {
      fill = AppColors.darkSurfaceElevated;
      fg = Colors.white;
    } else if (isActive) {
      fill = AppColors.primaryBlue;
      fg = Colors.white;
    } else {
      fill = Colors.white.withValues(alpha: 0.10);
      fg = DS.colour.textSecondary;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: DS.focus.animation,
        curve: DS.focus.curve,
        constraints: BoxConstraints(maxWidth: widget.maxWidth),
        padding: EdgeInsets.symmetric(
          horizontal: DS.space.md,
          vertical: DS.space.xs,
        ),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(DS.radius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.search, size: 16, color: fg),
            SizedBox(width: DS.space.xs),
            if (_editing)
              Flexible(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: true,
                  cursorColor: AppColors.primaryBlue,
                  style: DSText.bodyEmphasised.copyWith(color: fg),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    hintText: widget.placeholder,
                    hintStyle: DSText.bodyEmphasised.copyWith(
                      color: fg.withValues(alpha: 0.55),
                    ),
                  ),
                  onChanged: widget.onChanged,
                  onSubmitted: (_) {
                    if (widget.query.isEmpty) {
                      setState(() => _editing = false);
                    }
                  },
                ),
              )
            else
              Flexible(
                child: GestureDetector(
                  onTap: _startEditing,
                  behavior: HitTestBehavior.opaque,
                  child: Text(
                    widget.query.isEmpty
                        ? widget.placeholder
                        : '« ${widget.query} »',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DSText.bodyEmphasised.copyWith(color: fg),
                  ),
                ),
              ),
            if (isActive || _editing) ...<Widget>[
              SizedBox(width: DS.space.xs),
              GestureDetector(
                onTap: _clear,
                behavior: HitTestBehavior.opaque,
                child: Icon(Icons.close, size: 16, color: fg),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
