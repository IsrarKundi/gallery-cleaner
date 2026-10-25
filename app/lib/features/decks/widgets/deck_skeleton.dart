import 'package:flutter/material.dart';

import '../../../core/theme/theme_ext.dart';

/// Skeleton placeholder for a smart deck card while scanning or loading.
class DeckSkeletonCard extends StatelessWidget {
  const DeckSkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(context.sizes.radiusLg),
        border: Border.all(color: context.palette.border, width: 1),
      ),
      padding: EdgeInsets.all(context.sizes.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Top Row: Icon skeleton + Title/Subtitle skeleton + Pill skeleton
          Row(
            children: <Widget>[
              Container(
                width: context.sizes.giant,
                height: context.sizes.giant,
                decoration: BoxDecoration(
                  color: context.palette.surfaceVariant,
                  borderRadius: BorderRadius.circular(context.sizes.radiusMd),
                ),
              ),
              SizedBox(width: context.sizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 120,
                      height: 14,
                      decoration: BoxDecoration(
                        color: context.palette.surfaceVariant,
                        borderRadius: BorderRadius.circular(context.sizes.xs),
                      ),
                    ),
                    SizedBox(height: context.sizes.xs),
                    Container(
                      width: 170,
                      height: 11,
                      decoration: BoxDecoration(
                        color: context.palette.surfaceVariant,
                        borderRadius: BorderRadius.circular(context.sizes.xs),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: context.sizes.sm),
              Container(
                width: 56,
                height: 24,
                decoration: BoxDecoration(
                  color: context.palette.surfaceVariant,
                  borderRadius: BorderRadius.circular(context.sizes.pill),
                ),
              ),
            ],
          ),
          SizedBox(height: context.sizes.md),
          // Bottom Row: 4 placeholder tile boxes
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              const int slots = 4;
              final double spacing = context.sizes.sm;
              final double tileWidth =
                  (constraints.maxWidth - (spacing * (slots - 1))) / slots;
              final double tileHeight = tileWidth * 0.9;

              return Row(
                children: <Widget>[
                  for (int i = 0; i < slots; i++) ...<Widget>[
                    Container(
                      width: tileWidth,
                      height: tileHeight,
                      decoration: BoxDecoration(
                        color: context.palette.surfaceVariant,
                        borderRadius: BorderRadius.circular(
                          context.sizes.radiusMd,
                        ),
                      ),
                    ),
                    if (i < slots - 1) SizedBox(width: spacing),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
