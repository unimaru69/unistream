import 'package:flutter/material.dart';

import '../core/design_tokens.dart';
import '../core/theme_colors.dart';

/// Shared empty-state panel — icon + title + optional description + optional CTA.
/// Mirrors the Swift `EmptyStateView` on tvOS so both apps look the same.
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// When true, the panel centres itself and expands to fill the available
  /// space. Set to false when embedding inside a scrollable list.
  final bool expand;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      children: [
        Icon(icon, size: 60, color: colors.textSecondary.withValues(alpha: 0.6)),
        SizedBox(height: DS.space.md),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
        ),
        if (description != null) ...[
          SizedBox(height: DS.space.xs),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: DS.space.xl),
            child: Text(
              description!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
            ),
          ),
        ],
        if (actionLabel != null && onAction != null) ...[
          SizedBox(height: DS.space.lg),
          FilledButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    );

    if (!expand) return content;
    return Center(child: content);
  }
}
