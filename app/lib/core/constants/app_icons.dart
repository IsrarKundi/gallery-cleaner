import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

/// The single icon system for Klara (design.md §13).
///
/// Every icon in feature code and in the shared widget kit resolves
/// through a named constant here, so a glyph is re-chosen in exactly one
/// place. Feature code and core widgets must never name a pack glyph
/// class or the framework icon set directly.
///
/// Weight rules: Regular is the default weight. Fill marks
/// selected/active only. Duotone is reserved and no Duotone constant is
/// defined in v1.
///
/// Meaning → glyph → weight:
/// - keep → check → Regular
/// - delete → trash → Regular
/// - maybe → clock → Regular (decide later)
/// - favourite → heart → Regular
/// - favouriteActive → heart → Fill (selected only)
/// - undo → arrowCounterClockwise → Regular
/// - review → listChecks → Regular
/// - trash → trash → Regular (the Trash destination; same glyph as
///   delete, a different semantic constant)
/// - history → clockCounterClockwise → Regular
/// - error → warningCircle → Regular
/// - close → x → Regular
/// - check → check → Regular (generic confirmation; same glyph as keep,
///   a different semantic constant)
/// - filter → funnelSimple → Regular
/// - photos → image → Regular
/// - back → arrowLeft → Regular
/// - decks → squaresFour → Regular (smart-deck hub)
/// - duplicates → copySimple → Regular (duplicate groups)
/// - screenshots → imageSquare → Regular
/// - whatsapp → chatCircleText → Regular
/// - downloads → downloadSimple → Regular
/// - videos → filmStrip → Regular
/// - large → stackSimple → Regular
/// - old → calendarBlank → Regular
/// - bursts → images → Regular
/// - blurry → warningDiamond → Regular
/// - dark → moon → Regular
class AppIcons {
  AppIcons._();

  static const IconData keep = PhosphorIconsRegular.check;
  static const IconData delete = PhosphorIconsRegular.trash;
  static const IconData maybe = PhosphorIconsRegular.clock;
  static const IconData favourite = PhosphorIconsRegular.heart;
  static const IconData favouriteActive = PhosphorIconsFill.heart;
  static const IconData undo = PhosphorIconsRegular.arrowCounterClockwise;
  static const IconData review = PhosphorIconsRegular.listChecks;
  static const IconData trash = PhosphorIconsRegular.trash;
  static const IconData history = PhosphorIconsRegular.clockCounterClockwise;
  static const IconData error = PhosphorIconsRegular.warningCircle;
  static const IconData close = PhosphorIconsRegular.x;
  static const IconData check = PhosphorIconsRegular.check;
  static const IconData filter = PhosphorIconsRegular.funnelSimple;
  static const IconData photos = PhosphorIconsRegular.image;
  static const IconData back = PhosphorIconsRegular.arrowLeft;
  static const IconData decks = PhosphorIconsRegular.squaresFour;
  static const IconData duplicates = PhosphorIconsRegular.copySimple;
  static const IconData screenshots = PhosphorIconsRegular.imageSquare;
  static const IconData whatsapp = PhosphorIconsRegular.chatCircleText;
  static const IconData downloads = PhosphorIconsRegular.downloadSimple;
  static const IconData videos = PhosphorIconsRegular.filmStrip;
  static const IconData large = PhosphorIconsRegular.stackSimple;
  static const IconData old = PhosphorIconsRegular.calendarBlank;
  static const IconData bursts = PhosphorIconsRegular.images;
  static const IconData blurry = PhosphorIconsRegular.warningDiamond;
  static const IconData dark = PhosphorIconsRegular.moon;
  static const IconData onThisDay = PhosphorIconsRegular.calendarHeart;
  static const IconData goal = PhosphorIconsRegular.target;
  static const IconData streak = PhosphorIconsRegular.trophy;
  static const IconData share = PhosphorIconsRegular.shareNetwork;
  static const IconData settings = PhosphorIconsRegular.gear;
  static const IconData eye = PhosphorIconsRegular.eye;
  static const IconData eyeSlash = PhosphorIconsRegular.eyeSlash;

  /// Every constant, for tests that assert each one is a valid glyph.
  static const List<IconData> all = <IconData>[
    keep,
    delete,
    maybe,
    favourite,
    favouriteActive,
    undo,
    review,
    trash,
    history,
    error,
    close,
    check,
    filter,
    photos,
    back,
    decks,
    duplicates,
    screenshots,
    whatsapp,
    downloads,
    videos,
    large,
    old,
    bursts,
    blurry,
    dark,
    onThisDay,
    goal,
    streak,
    share,
    settings,
    eye,
    eyeSlash,
  ];
}
