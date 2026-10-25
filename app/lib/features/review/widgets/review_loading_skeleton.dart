import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/app_skeleton.dart';

/// Shimmer skeleton for the Review screen while delete-marked items
/// are loading from session.
class ReviewLoadingSkeleton extends StatelessWidget {
  const ReviewLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.sizes.screenPadding,
              context.sizes.screenPadding,
              context.sizes.screenPadding,
              context.sizes.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Bone(
                  width: 140,
                  height: 20,
                  borderRadius: BorderRadius.circular(context.sizes.radiusSm),
                ),
                SizedBox(height: context.sizes.xs),
                Bone(
                  width: 200,
                  height: 14,
                  borderRadius: BorderRadius.circular(context.sizes.radiusSm),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.all(context.sizes.screenPadding),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: context.sizes.sm,
                mainAxisSpacing: context.sizes.sm,
              ),
              itemCount: 12,
              itemBuilder: (BuildContext context, int index) {
                return Bone(
                  borderRadius: BorderRadius.circular(context.sizes.radiusMd),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
