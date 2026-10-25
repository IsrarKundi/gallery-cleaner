import 'package:flutter/material.dart';

import '../theme/theme_ext.dart';
import 'primary_button.dart';
import 'secondary_button.dart';

/// Empty state (design.md §6): small illustration icon above the text,
/// exactly one CTA. The CTA renders only when both [ctaLabel] and
/// [onCta] are given, so a state with no action never shows a dead
/// button.
///
/// Phase 3B deliberate exception: the photo-access DENIED state
/// carries a secondary action ([secondaryCtaLabel]/[onSecondaryCta])
/// — "Open settings" — because a permanently denied grant makes the
/// primary "Allow access" system prompt a no-op. Two recovery paths
/// for one blocked state, not two destinations; every other empty
/// state keeps exactly one CTA.
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.ctaLabel,
    this.onCta,
    this.secondaryCtaLabel,
    this.onSecondaryCta,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? ctaLabel;
  final VoidCallback? onCta;
  final String? secondaryCtaLabel;
  final VoidCallback? onSecondaryCta;

  @override
  Widget build(BuildContext context) {
    final String? ctaLabel = this.ctaLabel;
    final VoidCallback? onCta = this.onCta;
    final String? secondaryCtaLabel = this.secondaryCtaLabel;
    final VoidCallback? onSecondaryCta = this.onSecondaryCta;
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
            if (secondaryCtaLabel != null &&
                onSecondaryCta != null) ...<Widget>[
              SizedBox(height: context.sizes.sm),
              SecondaryButton(
                label: secondaryCtaLabel,
                onPressed: onSecondaryCta,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
