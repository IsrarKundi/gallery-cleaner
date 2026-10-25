// Display metadata for each smart deck: string key + icon. One
// place, so the hub, the smart-deck screen and tests agree on names
// and glyphs. Icons resolve through AppIcons only (design.md §13).

import 'package:flutter/material.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/strings/app_strings.dart';
import '../../../services/detection/smart_decks.dart';

/// String key for a deck's display name.
String smartDeckTitleKey(SmartDeckId id) {
  switch (id) {
    case SmartDeckId.screenshots:
      return AppStrings.deckScreenshots;
    case SmartDeckId.whatsapp:
      return AppStrings.deckWhatsapp;
    case SmartDeckId.downloads:
      return AppStrings.deckDownloads;
    case SmartDeckId.videos:
      return AppStrings.deckVideos;
    case SmartDeckId.large:
      return AppStrings.deckLarge;
    case SmartDeckId.old:
      return AppStrings.deckOld;
    case SmartDeckId.bursts:
      return AppStrings.deckBursts;
    case SmartDeckId.blurry:
      return AppStrings.deckBlurry;
    case SmartDeckId.dark:
      return AppStrings.deckDark;
    case SmartDeckId.duplicates:
      return AppStrings.deckDuplicates;
    case SmartDeckId.onThisDay:
      return AppStrings.deckOnThisDay;
  }
}

/// Icon for a deck (AppIcons constants only).
IconData smartDeckIcon(SmartDeckId id) {
  switch (id) {
    case SmartDeckId.screenshots:
      return AppIcons.screenshots;
    case SmartDeckId.whatsapp:
      return AppIcons.whatsapp;
    case SmartDeckId.downloads:
      return AppIcons.downloads;
    case SmartDeckId.videos:
      return AppIcons.videos;
    case SmartDeckId.large:
      return AppIcons.large;
    case SmartDeckId.old:
      return AppIcons.old;
    case SmartDeckId.bursts:
      return AppIcons.bursts;
    case SmartDeckId.blurry:
      return AppIcons.blurry;
    case SmartDeckId.dark:
      return AppIcons.dark;
    case SmartDeckId.duplicates:
      return AppIcons.duplicates;
    case SmartDeckId.onThisDay:
      return AppIcons.onThisDay;
  }
}

/// Hub display order (same as the SmartDeckId declaration order).
const List<SmartDeckId> smartDeckOrder = SmartDeckId.values;
