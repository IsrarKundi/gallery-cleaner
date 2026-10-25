// Phase 4.3: the hub timeline's incremental accumulators must
// produce exactly the same summaries as the batch grouping over
// the full asset list (same totals, years, month counts/bytes and
// first-seen covers), while a rebuild only reads O(months).
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:klara/features/decks/controller/decks_controller.dart';
import 'package:klara/features/decks/model/timeline_grouping.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_service.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/services/detection/photo_analysis.dart';
import 'package:klara/services/trash/trash_entry.dart';

MediaAsset _video(String id, DateTime date, int bytes) {
  return MediaAsset(
    id: id,
    type: MediaAssetType.video,
    width: 100,
    height: 100,
    sizeBytes: bytes,
    createDate: date,
    title: id,
    albumName: 'All',
  );
}

class _FakeMedia implements MediaService {
  _FakeMedia(this.all);

  /// Full asset list in scan order; pages are sliced by the
  /// requested (page, pageSize), honouring the scanner's
  /// short-page-ends-the-scan contract.
  final List<MediaAsset> all;

  @override
  Future<Result<MediaPermission>> requestPermission() async =>
      const Success<MediaPermission>(MediaPermission.grantedFull);

  @override
  Future<Result<void>> presentLimitedSelection() async =>
      const Success<void>(null);

  @override
  Future<Result<void>> openAppSettings() async => const Success<void>(null);

  @override
  Future<Result<List<MediaAlbum>>> getAlbums() async =>
      const Success<List<MediaAlbum>>(<MediaAlbum>[]);

  @override
  Future<Result<List<MediaAsset>>> getAssets({
    String? albumId,
    String? monthKey,
    MediaFilterType type = MediaFilterType.all,
    int page = 0,
    int pageSize = 50,
  }) async {
    final int start = page * pageSize;
    if (start >= all.length) {
      return const Success<List<MediaAsset>>(<MediaAsset>[]);
    }
    final int end = (start + pageSize).clamp(0, all.length);
    return Success<List<MediaAsset>>(all.sublist(start, end));
  }

  @override
  Future<Result<List<MediaAsset>>> getAssetsByIds(List<String> ids) async =>
      const Success<List<MediaAsset>>(<MediaAsset>[]);

  @override
  Future<Result<Uint8List>> getThumbnail(
    String assetId,
    int size, {
    int quality = 85,
  }) async => Success<Uint8List>(Uint8List(0));
}

class _FakeLocal implements LocalService {
  @override
  Future<Result<int>> pruneAnalyses(Set<String> liveIds) async {
    return const Success<int>(0);
  }

  @override
  Future<Result<void>> saveSession(DeckSession session) async =>
      const Success<void>(null);

  @override
  Future<Result<DeckSession?>> loadSession(String filterKey) async =>
      const Success<DeckSession?>(null);

  @override
  Future<Result<List<DeckSession>>> listSessions() async =>
      const Success<List<DeckSession>>(<DeckSession>[]);

  @override
  Future<Result<Map<String, DateTime>>> loadSnoozes() async =>
      const Success<Map<String, DateTime>>(<String, DateTime>{});

  @override
  Future<Result<void>> setSnooze(String assetId, DateTime? until) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> clearSnoozes(List<String> ids) async =>
      const Success<void>(null);

  @override
  Future<void> flushPendingWrites() async {}

  @override
  Future<Result<double>> loadGoalTargetMb() async => const Success<double>(0);

  @override
  Future<Result<void>> saveGoalTargetMb(double mb) async =>
      const Success<void>(null);

  @override
  Future<Result<List<DateTime>>> loadCompletionDays() async =>
      const Success<List<DateTime>>(<DateTime>[]);

  @override
  Future<Result<void>> recordCompletionDay(DateTime day) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> recordTrashed(List<TrashEntry> entries) async =>
      const Success<void>(null);

  @override
  Future<Result<List<TrashEntry>>> loadTrashEntries() async =>
      const Success<List<TrashEntry>>(<TrashEntry>[]);

  @override
  Future<Result<void>> removeTrashEntries(List<String> ids) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> clearTrashEntries() async => const Success<void>(null);

  @override
  Future<Result<void>> appendHistory(HistoryRecord record) async =>
      const Success<void>(null);

  @override
  Future<Result<List<HistoryRecord>>> loadHistory() async =>
      const Success<List<HistoryRecord>>(<HistoryRecord>[]);

  @override
  Future<Result<bool>> isTutorialSeen() async => const Success<bool>(true);

  @override
  Future<Result<void>> setTutorialSeen(bool seen) async =>
      const Success<void>(null);

  @override
  Future<Result<AppSettings>> loadSettings() async =>
      const Success<AppSettings>(AppSettings());

  @override
  Future<Result<void>> saveSettings(AppSettings settings) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> saveAnalyses(List<PhotoAnalysis> analyses) async =>
      const Success<void>(null);

  @override
  Future<Result<Map<String, PhotoAnalysis>>> loadAnalyses() async =>
      const Success<Map<String, PhotoAnalysis>>(<String, PhotoAnalysis>{});
}

void main() {
  test('incremental timeline equals batch grouping over two pages', () async {
    // Scan order (newest first), 60 assets so the scanner's
    // default 50-per-page paging yields two pages: page 0 =
    // Oct 2026 x20, Sep 2026 x15, Dec 2025 x15; page 1 =
    // Oct 2026 x5 (later in scan order), Jan 2024 x5.
    final List<MediaAsset> assets = <MediaAsset>[
      for (int i = 0; i < 20; i++)
        _video('oct-$i', DateTime(2026, 10, 20 - i % 20), 1000 + i),
      for (int i = 0; i < 15; i++)
        _video('sep-$i', DateTime(2026, 9, 15), 2000 + i),
      for (int i = 0; i < 15; i++)
        _video('dec-$i', DateTime(2025, 12, 1), 3000 + i),
      for (int i = 0; i < 5; i++)
        _video('oct-late-$i', DateTime(2026, 10, 1), 500 + i),
      for (int i = 0; i < 5; i++)
        _video('jan-$i', DateTime(2024, 1, 10), 600 + i),
    ];
    final DecksController controller = DecksController(
      media: _FakeMedia(assets),
      local: _FakeLocal(),
    );
    await controller.init();

    final List<MediaAsset> all = controller.allAssets;
    expect(all.length, 60);

    // Total bytes: incremental == batch fold.
    final int batchTotal = all.fold<int>(
      0,
      (int s, MediaAsset a) => s + a.sizeBytes,
    );
    expect(controller.timelineTotalBytes, batchTotal);

    // Years: incremental == batch, newest first.
    expect(controller.timelineYears, availableYearsFor(all));
    expect(controller.timelineYears, <int>[2026, 2025, 2024]);

    // Months per year: same keys, counts, bytes and covers.
    for (final int year in <int>[2026, 2025, 2024]) {
      final List<MonthSummary> incremental = controller.monthsForYear(year);
      final List<MonthSummary> batch = groupAssetsByMonth(
        assets: all,
        targetYear: year,
      );
      expect(
        incremental.map((MonthSummary m) => m.monthKey).toList(),
        batch.map((MonthSummary m) => m.monthKey).toList(),
      );
      for (int i = 0; i < batch.length; i++) {
        expect(incremental[i].count, batch[i].count);
        expect(incremental[i].totalBytes, batch[i].totalBytes);
        expect(incremental[i].coverAsset?.id, batch[i].coverAsset?.id);
      }
    }

    // Ascending order is the reverse of descending.
    final List<MonthSummary> desc = controller.monthsForYear(2026);
    final List<MonthSummary> asc = controller.monthsForYear(
      2026,
      ascending: true,
    );
    expect(
      asc.map((MonthSummary m) => m.monthKey).toList(),
      desc.map((MonthSummary m) => m.monthKey).toList().reversed.toList(),
    );

    // The first asset seen for Oct 2026 is the cover, not a
    // later page-1 asset.
    expect(controller.monthsForYear(2026).first.coverAsset?.id, 'oct-0');
    // Unknown year yields no months.
    expect(controller.monthsForYear(1999), isEmpty);
  });
}
