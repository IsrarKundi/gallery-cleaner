import 'package:flutter/material.dart';

/// The single source of layout numbers for Klara (design.md §4, §8, §10).
///
/// 8dp grid; a size not in this scale does not exist. Fixed logical pixels
/// only: flutter_screenutil and percentage-of-screen sizing are forbidden.
/// Motion follows the 100 / 200 / 300 / 400ms ladder with the two curves
/// below; no per-component bounce.
class AppSizes {
  const AppSizes();

  // 8dp grid scale.
  double get xxs => 2;
  double get xs => 4;
  double get sm => 8;
  double get md => 12;
  double get lg => 16;
  double get xl => 20;
  double get xxl => 24;
  double get xxxl => 32;
  double get huge => 40;
  double get giant => 48;

  // Layout.
  double get screenPadding => 16;
  double get cardPadding => 16;

  // Radii.
  double get radiusSm => 8;
  double get radiusMd => 12;
  double get radiusLg => 16;
  double get radiusXl => 20;
  double get radiusSheet => 28;
  double get pill => 999;

  // Buttons and targets (design.md §5, §9).
  // Primary height 52 sits inside the 48-56dp range; compact is 40.
  // Every interactive element keeps a 48dp hit area.
  double get buttonPrimary => 46;
  double get buttonCompact => 40;
  double get hitArea => 48;
  double get listRowMin => 56;
  double get appBar => 56;

  // Glyph sizes.
  double get iconSm => 20;
  double get iconMd => 24;
  double get iconLg => 28;

  // Disabled state (design.md §5: ~0.38-0.5 opacity). The top of the
  // range keeps a disabled label readable; the caller always adds a
  // caption explaining why the button is disabled.
  double get disabledOpacity => 0.5;

  // Motion durations (design.md §8).
  Duration get motionFast => const Duration(milliseconds: 100);
  Duration get motionNormal => const Duration(milliseconds: 200);
  Duration get motionSlow => const Duration(milliseconds: 300);
  Duration get motionSlower => const Duration(milliseconds: 400);

  // Motion curves (design.md §8).
  Cubic get easeOut => const Cubic(0.2, 0.0, 0.0, 1.0);
  Cubic get spring => const Cubic(0.34, 1.56, 0.64, 1.0);

  // Snackbar visibility (not motion; kept here so no widget file invents
  // its own duration).
  Duration get snackBarDuration => const Duration(seconds: 4);

  // Duplicates selection mark (Stage 7): the round spare/select
  // mark on a duplicate photo — the visible circle; its hit area
  // is the standard 48dp (hitArea above).
  double get selectionMark => 28;

  // Stage 5 artwork (ADR-020): the finish-screen popper and the
  // review-sheet kitten render at celebration width; the two
  // empty-state pictures render smaller (design.md §6:
  // illustration small, above the CTA, never full-screen).
  double get celebrationArt => 200;
  double get emptyArt => 160;

  // Splash (design.md §13): logo width on the splash screen, and the
  // hold-timer fallback. The Lottie itself is ~1.67s, so the timer only
  // fires if Lottie playback fails; it is cancelled on Lottie finish.
  double get splashLogoWidth => 80;
  // Height matching the generated logo aspect (755:200 viewBox).
  double get splashLogoHeight => 53;
  Duration get splashHold => const Duration(milliseconds: 2000);
  // Reduced-motion splash (Phase 2.2): no Lottie runs, so the 3.0s
  // fallback would be the whole wait. A short hold lets the brand
  // mark register, then the splash exits — far below the fallback.
  Duration get splashReducedMotionHold => const Duration(milliseconds: 800);
}
