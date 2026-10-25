import 'package:flutter/material.dart';

import '../theme/theme_ext.dart';

/// Full-screen loading state: the content stays mounted underneath a
/// scrim with a centred spinner and an optional message. Used for jobs
/// of unknown duration; jobs over ~4 seconds use a determinate progress
/// bar in the feature view instead (design.md §5, §6).
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    super.key,
    required this.child,
    required this.isLoading,
    this.message,
  });

  final Widget child;
  final bool isLoading;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final String? message = this.message;
    return Stack(
      children: <Widget>[
        child,
        if (isLoading) ...<Widget>[
          ModalBarrier(color: context.palette.scrim),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                CircularProgressIndicator(color: context.palette.onPrimary),
                if (message != null) ...<Widget>[
                  SizedBox(height: context.sizes.md),
                  Text(
                    message,
                    style: context.textStyles.bodyMedium.copyWith(
                      color: context.palette.onPrimary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
