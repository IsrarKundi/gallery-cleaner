import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../theme/theme_ext.dart';

/// App-wide common skeleton shimmer wrapper (design.md §10).
/// Wrap any widget or screen layout with [AppSkeleton] to automatically
/// render a matching, animated shimmer skeleton during loading without
/// hand-crafting separate skeleton screens.
class AppSkeleton extends StatelessWidget {
  const AppSkeleton({
    super.key,
    required this.child,
    this.enabled = true,
    this.ignoreContainers = false,
  });

  final Widget child;
  final bool enabled;
  final bool ignoreContainers;

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: enabled,
      ignoreContainers: ignoreContainers,
      containersColor: context.palette.surfaceVariant,
      effect: ShimmerEffect(
        baseColor: context.palette.surfaceVariant,
        highlightColor: context.palette.surface,
        duration: const Duration(milliseconds: 1500),
      ),
      child: child,
    );
  }
}

/// Simple helper to create a rounded skeleton box placeholder.
class AppSkeletonBox extends StatelessWidget {
  const AppSkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.radius,
  });

  final double width;
  final double height;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    return Bone(
      width: width,
      height: height,
      borderRadius: BorderRadius.circular(radius ?? context.sizes.radiusMd),
    );
  }
}
