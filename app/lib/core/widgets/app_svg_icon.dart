import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Renders a custom SVG icon asset from [AppIcons] (Iconify-sourced,
/// design.md §13). All assets use `currentColor` paths, so [color]
/// tints the whole glyph via a srcIn filter — the same way an
/// [Icon] follows its ambient colour.
class AppSvgIcon extends StatelessWidget {
  const AppSvgIcon({
    super.key,
    required this.asset,
    required this.size,
    required this.color,
  });

  final String asset;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
