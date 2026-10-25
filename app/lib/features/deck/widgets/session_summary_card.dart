// Finished-session summary card (Phase 2B, requirements §7).
// Layout only: counts arrive precomputed as a [SessionSummary].
// The card never reports trashed MB as freed and never calls
// marked MB freed — the delete line reads "to be freed".
// Reuse (deliberate exception, like SwipeCard/DeckActionBar):
// smart-deck finishes render this same card with [onShare] null,
// so they show the counts without a share button.
//
// Capture: the view wraps this card in a RepaintBoundary and
// passes its key to [captureBoundaryPng] when the user taps
// Share; a null result means capture failed and the caller shares
// the same numbers as text instead (the documented fallback).

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/utils/formatters.dart';
import '../model/retention.dart';

/// Renders [boundaryKey]'s RepaintBoundary to PNG bytes, or null
/// when there is nothing to capture (not laid out, render failed).
Future<Uint8List?> captureBoundaryPng(GlobalKey boundaryKey) async {
  try {
    final RenderObject? renderObject = boundaryKey.currentContext
        ?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      return null;
    }
    final ui.Image image = await renderObject.toImage(pixelRatio: 2);
    final ByteData? bytes = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return bytes?.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}

class SessionSummaryCard extends StatelessWidget {
  const SessionSummaryCard({super.key, required this.summary, this.onShare});

  final SessionSummary summary;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          AppStrings.tr(AppStrings.summaryTitle),
          style: context.textStyles.titleLarge,
        ),
        SizedBox(height: context.sizes.lg),
        _Row(
          icon: AppIcons.photos,
          text: AppStrings.tr(AppStrings.summaryReviewed, <String, String>{
            'count': Formatters.formatCount(summary.reviewed),
          }),
        ),
        _Row(
          icon: AppIcons.keep,
          text: AppStrings.tr(AppStrings.summaryKept, <String, String>{
            'count': Formatters.formatCount(summary.kept),
          }),
        ),
        _Row(
          icon: AppIcons.delete,
          text: AppStrings.tr(AppStrings.summaryDeleteMarked, <String, String>{
            'count': Formatters.formatCount(summary.deleteMarked),
            'size': Formatters.formatBytes(summary.deleteMarkedBytes),
          }),
        ),
        _Row(
          icon: AppIcons.maybe,
          text: AppStrings.tr(AppStrings.summaryMaybe, <String, String>{
            'count': Formatters.formatCount(summary.maybe),
          }),
        ),
        _Row(
          icon: AppIcons.favourite,
          text: AppStrings.tr(AppStrings.summaryFavourite, <String, String>{
            'count': Formatters.formatCount(summary.favourite),
          }),
        ),
        if (onShare != null) ...<Widget>[
          SizedBox(height: context.sizes.xl),
          SizedBox(
            width: double.infinity,
            height: context.sizes.buttonPrimary,
            child: FilledButton.icon(
              onPressed: onShare,
              icon: Icon(AppIcons.share, size: context.sizes.iconSm),
              label: Text(AppStrings.tr(AppStrings.summaryShare)),
            ),
          ),
        ],
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.sizes.xs),
      child: Row(
        children: <Widget>[
          Icon(icon, size: context.sizes.iconSm),
          SizedBox(width: context.sizes.sm),
          Expanded(child: Text(text, style: context.textStyles.bodyMedium)),
        ],
      ),
    );
  }
}
