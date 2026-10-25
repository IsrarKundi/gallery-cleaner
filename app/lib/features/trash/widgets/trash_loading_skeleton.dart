import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/app_skeleton.dart';

/// Shimmer skeleton for the Trash screen while entries are loading.
class TrashLoadingSkeleton extends StatelessWidget {
  const TrashLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(vertical: context.sizes.sm),
        itemCount: 8,
        separatorBuilder: (_, _) => SizedBox(height: context.sizes.xs),
        itemBuilder: (BuildContext context, int index) {
          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.sizes.screenPadding,
              vertical: context.sizes.xs,
            ),
            child: Row(
              children: <Widget>[
                Bone(
                  width: 44,
                  height: 44,
                  borderRadius: BorderRadius.circular(context.sizes.radiusMd),
                ),
                SizedBox(width: context.sizes.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Bone(
                        width: 80,
                        height: 16,
                        borderRadius: BorderRadius.circular(
                          context.sizes.radiusSm,
                        ),
                      ),
                      SizedBox(height: context.sizes.xs),
                      Bone(
                        width: 190,
                        height: 12,
                        borderRadius: BorderRadius.circular(
                          context.sizes.radiusSm,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: context.sizes.sm),
                Bone(
                  width: 58,
                  height: 28,
                  borderRadius: BorderRadius.circular(context.sizes.radiusSm),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
