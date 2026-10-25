import 'package:flutter/material.dart';

import '../theme/theme_ext.dart';

/// Section heading: title plus an optional subtitle and an optional
/// tertiary text action. The action is a text button only because it
/// never performs a destructive action (design.md §5).
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final String? subtitle = this.subtitle;
    final String? actionLabel = this.actionLabel;
    final VoidCallback? onAction = this.onAction;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: Text(title, style: context.textStyles.titleMedium)),
            if (actionLabel != null && onAction != null)
              TextButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
        if (subtitle != null)
          Text(
            subtitle,
            style: context.textStyles.bodySmall.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
      ],
    );
  }
}
