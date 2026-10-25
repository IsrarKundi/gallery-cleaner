import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/app_skeleton.dart';

/// Full-screen shimmer skeleton placeholder for the swipe cleaning deck (Home).
class DeckHomeSkeleton extends StatelessWidget {
  const DeckHomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      child: Column(
        children: <Widget>[
          // Main Swipe Card skeleton
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.sizes.screenPadding,
                vertical: context.sizes.xs,
              ),
              child: Bone(
                width: double.infinity,
                height: double.infinity,
                borderRadius: BorderRadius.circular(context.sizes.radiusLg),
              ),
            ),
          ),
          // Caption line skeleton
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.sizes.screenPadding,
              vertical: context.sizes.sm,
            ),
            child: Bone(
              width: 180,
              height: 14,
              borderRadius: BorderRadius.circular(context.sizes.pill),
            ),
          ),
          // Action buttons skeleton
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.sizes.screenPadding,
              context.sizes.xs,
              context.sizes.screenPadding,
              context.sizes.md,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(5, (_) => const Bone.circle(size: 48)),
            ),
          ),
        ],
      ),
    );
  }
}
