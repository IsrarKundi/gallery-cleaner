import 'package:flutter/material.dart';

import '../theme/theme_ext.dart';

/// Primary filled action (design.md §5): pill radius, 52dp height,
/// icon + label. While [isLoading] the spinner replaces the label and
/// the button is disabled to prevent double-submission. A disabled
/// button renders at reduced opacity; the caller shows a caption
/// explaining why it is disabled.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  bool get _enabled => onPressed != null && !isLoading;

  @override
  Widget build(BuildContext context) {
    final IconData? icon = this.icon;
    return Opacity(
      opacity: _enabled ? 1 : context.sizes.disabledOpacity,
      child: SizedBox(
        height: context.sizes.buttonPrimary,
        width: double.infinity,
        child: FilledButton(
          onPressed: _enabled ? onPressed : null,
          child: isLoading
              ? SizedBox(
                  height: context.sizes.iconSm,
                  width: context.sizes.iconSm,
                  child: CircularProgressIndicator(
                    color: context.palette.onPrimary,
                    strokeWidth: context.sizes.xxs,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (icon != null) ...<Widget>[
                      Icon(icon, size: context.sizes.iconSm),
                      SizedBox(width: context.sizes.sm),
                    ],
                    Text(label),
                  ],
                ),
        ),
      ),
    );
  }
}
