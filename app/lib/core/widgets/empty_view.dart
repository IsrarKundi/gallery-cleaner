import 'package:flutter/material.dart';

import '../theme/theme_ext.dart';
import 'primary_button.dart';

/// Empty state (design.md §6): small illustration icon above the text,
/// exactly one CTA. The CTA renders only when both [ctaLabel] and
/// [onCta] are given, so a state with no action never shows a dead
/// button.
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.ctaLabel,
    this.onCta,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? ctaLabel;
  final VoidCallback? onCta;

  @override
  Widget build(BuildContext context) {
    final String? ctaLabel = this.ctaLabel;
    final VoidCallback? onCta = this.onCta;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.sizes.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: context.sizes.iconLg,
              color: context.palette.textSecondary,
            ),
            SizedBox(height: context.sizes.md),
            Text(title, style: context.textStyles.titleLarge),
            SizedBox(height: context.sizes.sm),
            Text(
              message,
              style: context.textStyles.bodyMedium.copyWith(
                color: context.palette.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (ctaLabel != null && onCta != null) ...<Widget>[
              SizedBox(height: context.sizes.lg),
              PrimaryButton(label: ctaLabel, onPressed: onCta),
            ],
          ],
        ),
      ),
    );
  }
}
