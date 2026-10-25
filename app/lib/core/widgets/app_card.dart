import 'package:flutter/material.dart';

import '../theme/theme_ext.dart';

/// Tonal card (design.md §6): flat tonal surface, 16dp radius, no
/// shadow. Photos themselves are never placed in cards; the grid is
/// the content. Tapping is optional and ripples through the card.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.onTap, this.padding});

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.palette.surfaceVariant,
      borderRadius: BorderRadius.circular(context.sizes.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(context.sizes.radiusLg),
        child: Padding(
          padding: padding ?? EdgeInsets.all(context.sizes.cardPadding),
          child: child,
        ),
      ),
    );
  }
}
