import 'package:flutter/material.dart';

import '../theme/theme_ext.dart';

/// Secondary outlined action (design.md §5): 12dp radius, 48dp
/// height. Phase 3B correction: the old "40dp visual inside a 48dp
/// box" pattern did NOT give a 48dp tap target — a tap test proved
/// edge taps miss a 40dp button centred in a 48dp box — so the
/// button itself fills 48dp. Same disabled-opacity rule as
/// [PrimaryButton]: the caller explains why it is disabled.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
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
        height: context.sizes.hitArea,
        width: double.infinity,
        child: OutlinedButton(
          onPressed: _enabled ? onPressed : null,
          child: isLoading
              ? SizedBox(
                  height: context.sizes.iconSm,
                  width: context.sizes.iconSm,
                  child: CircularProgressIndicator(
                    color: context.palette.textPrimary,
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
