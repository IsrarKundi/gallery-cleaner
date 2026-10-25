import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/widgets/app_skeleton.dart';

/// Loading skeleton for DecksView matching the redesigned mock layout.
class DecksLoadingSkeleton extends StatelessWidget {
  const DecksLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      child: ListView(
        padding: EdgeInsets.symmetric(vertical: context.sizes.sm),
        physics: const NeverScrollableScrollPhysics(),
        children: <Widget>[
          // Top Header skeleton
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.sizes.screenPadding,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  AppStrings.tr(AppStrings.appTitle),
                  style: context.textStyles.headlineLarge.copyWith(
                    fontWeight: FontWeight.w800,
                    color: context.palette.textPrimary,
                    fontSize: 26,
                  ),
                ),
                Bone(
                  width: 120,
                  height: 32,
                  borderRadius: BorderRadius.circular(context.sizes.pill),
                ),
              ],
            ),
          ),
          SizedBox(height: context.sizes.md),
          // Hero Card skeleton
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.sizes.screenPadding,
            ),
            child: Bone(
              width: double.infinity,
              height: 180,
              borderRadius: BorderRadius.circular(context.sizes.radiusLg),
            ),
          ),
          SizedBox(height: context.sizes.lg),
          // Timeline Header skeleton
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.sizes.screenPadding,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  AppStrings.tr(AppStrings.timelineTitle),
                  style: context.textStyles.titleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Bone(
                  width: 60,
                  height: 14,
                  borderRadius: BorderRadius.circular(context.sizes.pill),
                ),
              ],
            ),
          ),
          SizedBox(height: context.sizes.md),
          // Month cards skeleton
          SizedBox(
            height: 180,
            child: ListView.separated(
              padding: EdgeInsets.symmetric(
                horizontal: context.sizes.screenPadding,
              ),
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 3,
              separatorBuilder: (_, _) => SizedBox(width: context.sizes.md),
              itemBuilder: (_, _) => Bone(
                width: 140,
                height: 180,
                borderRadius: BorderRadius.circular(context.sizes.radiusLg),
              ),
            ),
          ),
          SizedBox(height: context.sizes.lg),
          // Smart Decks skeleton
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.sizes.screenPadding,
            ),
            child: Text(
              AppStrings.tr(AppStrings.decksTitle),
              style: context.textStyles.titleLarge.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(height: context.sizes.md),
          SizedBox(
            height: 220,
            child: ListView.separated(
              padding: EdgeInsets.symmetric(
                horizontal: context.sizes.screenPadding,
              ),
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 2,
              separatorBuilder: (_, _) => SizedBox(width: context.sizes.md),
              itemBuilder: (_, _) => const DeckGridSkeleton(),
            ),
          ),
        ],
      ),
    );
  }
}

/// 2x2 Thumbnail grid card skeleton.
class DeckGridSkeleton extends StatelessWidget {
  const DeckGridSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Bone(
          width: 158,
          height: 158,
          borderRadius: BorderRadius.circular(context.sizes.radiusLg),
        ),
        SizedBox(height: context.sizes.xs),
        Bone(
          width: 80,
          height: 14,
          borderRadius: BorderRadius.circular(context.sizes.pill),
        ),
        SizedBox(height: context.sizes.xxs),
        Bone(
          width: 50,
          height: 10,
          borderRadius: BorderRadius.circular(context.sizes.pill),
        ),
      ],
    );
  }
}
