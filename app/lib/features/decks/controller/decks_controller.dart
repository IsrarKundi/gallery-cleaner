// Smart-deck hub state (requirements §7, Phase 2).
//
// The hub NEVER blocks on a full-library scan before showing
// anything: the scanner reports each page, and this controller
// appends each page's assets to their decks immediately, so rows
// fill in as their counts become known. A determinate progress bar
// (scanned count + % against the estimated library total) sits at
// the top while scanning. Bursts and duplicates are list-level
// results, so their rows stay in "still scanning" until the scan
// completes; every other deck updates per page.
//
// Failure handling: a denied permission shows the denied state; a
// failed page keeps whatever arrived and flips to error only when
// nothing arrived at all (partial results beat no results).

import 'package:get/get.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/utils/result.dart';
import '../../../services/detection/grouping.dart';
import '../../../services/detection/library_scanner.dart';
import '../../../services/detection/photo_analysis.dart';
import '../../../services/detection/smart_decks.dart';
import '../../../services/local/local_service.dart';
import '../../../services/media/media_asset.dart';
import '../../../services/media/media_service.dart';
import '../model/decks_status.dart';
import '../model/smart_deck_launch.dart';

class DecksController extends GetxController {
  DecksController({required this.media, required this.local});

  final MediaService media;
  final LocalService local;

  /// Slider default, shared with the Duplicates screen: the hub's
  /// duplicates row counts groups at this threshold.
  static const int duplicatesThreshold = 5;

  final Rx<DecksStatus> status = DecksStatus.loading.obs;
  final RxString errorKey = ''.obs;
  final RxInt scanned = 0.obs;
  final Rx<int?> estimatedTotal = Rx<int?>(null);
  final RxBool scanComplete = false.obs;
  final RxMap<SmartDeckId, List<MediaAsset>> deckAssets =
      <SmartDeckId, List<MediaAsset>>{}.obs;
  final RxMap<String, PhotoAnalysis> analyses = <String, PhotoAnalysis>{}.obs;

  final List<MediaAsset> _allAssets = <MediaAsset>[];

  /// 0-1 progress, or null when the library total is unknown.
  double? get progress {
    final int? total = estimatedTotal.value;
    if (total == null || total <= 0) {
      return null;
    }
    return (scanned.value / total).clamp(0, 1).toDouble();
  }

  bool get isScanning => status.value == DecksStatus.scanning;

  List<MediaAsset> assetsFor(SmartDeckId id) {
    return deckAssets[id] ?? <MediaAsset>[];
  }

  int totalBytesFor(SmartDeckId id) {
    return assetsFor(id).fold<int>(0, (int sum, MediaAsset a) {
      return sum + a.sizeBytes;
    });
  }

  /// List-level decks (bursts, duplicates) are ready only when the
  /// scan completes; the rest are ready as soon as pages arrive.
  bool deckReady(SmartDeckId id) {
    if (id == SmartDeckId.bursts || id == SmartDeckId.duplicates) {
      return scanComplete.value;
    }
    return scanned.value > 0 || scanComplete.value;
  }

  @override
  void onInit() {
    super.onInit();
    init();
  }

  Future<void> init() async {
    status.value = DecksStatus.loading;
    final Result<MediaPermission> permission = await media.requestPermission();
    final bool granted = permission.fold(
      onSuccess: (MediaPermission value) => value != MediaPermission.denied,
      onFailure: (AppFailure failure) {
        errorKey.value = failure.messageKey;
        return false;
      },
    );
    if (!granted) {
      status.value = DecksStatus.denied;
      if (errorKey.value.isEmpty) {
        errorKey.value = AppStrings.errorMediaPermission;
      }
      return;
    }
    status.value = DecksStatus.scanning;
    await _scan();
  }

  Future<void> retry() async {
    _allAssets.clear();
    deckAssets.clear();
    analyses.clear();
    scanned.value = 0;
    estimatedTotal.value = null;
    scanComplete.value = false;
    await init();
  }

  Future<void> _scan() async {
    final DateTime now = DateTime.now();
    final LibraryScanner scanner = LibraryScanner(media: media, local: local);
    final LibraryScan result = await scanner.scan(
      onPage: (List<MediaAsset> page, Map<String, PhotoAnalysis> found) {
        _allAssets.addAll(page);
        analyses.assignAll(found);
        for (final MediaAsset asset in page) {
          for (final SmartDeckId id in decksForAsset(asset, found, now)) {
            deckAssets[id] = <MediaAsset>[...assetsFor(id), asset];
          }
        }
        scanned.value = _allAssets.length;
      },
      onProgress: (int count, int? total) {
        scanned.value = count;
        estimatedTotal.value = total;
      },
    );
    scanComplete.value = true;
    // List-level decks resolve only over the full list.
    final Set<String> burstIds = burstAssetIds(_allAssets);
    deckAssets[SmartDeckId.bursts] = _allAssets
        .where((MediaAsset a) => burstIds.contains(a.id))
        .toList();
    final List<DuplicateGroup> groups = groupAssets(
      assets: _allAssets,
      analyses: result.analyses,
      threshold: duplicatesThreshold,
    );
    deckAssets[SmartDeckId.duplicates] = <MediaAsset>[
      for (final DuplicateGroup group in groups) ...group.assets,
    ];
    if (result.pageFailed && _allAssets.isEmpty) {
      status.value = DecksStatus.error;
      errorKey.value = AppStrings.errorMediaLoad;
      return;
    }
    status.value = DecksStatus.ready;
  }

  /// Opens a deck: duplicates go to their own screen; every other
  /// deck opens as a swipe deck with its precomputed assets.
  void openDeck(SmartDeckId id) {
    if (id == SmartDeckId.duplicates) {
      Get.toNamed<dynamic>(AppRoutes.duplicates);
      return;
    }
    Get.toNamed<dynamic>(
      AppRoutes.smartDeck,
      arguments: SmartDeckLaunch(deckId: id, assets: assetsFor(id)),
    );
  }
}
