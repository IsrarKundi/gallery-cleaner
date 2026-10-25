// Phase 3.4: keyed review/trash items keep their identity when
// the set shrinks — the remaining row still shows its own photo.
// No device.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:klara/core/theme/app_theme.dart';
import 'package:klara/core/utils/formatters.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/features/review/controller/review_controller.dart';
import 'package:klara/features/review/view/review_view.dart';
import 'package:klara/features/trash/controller/trash_controller.dart';
import 'package:klara/features/trash/view/trash_view.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_service.dart';
import 'package:klara/services/trash/trash_entry.dart';
import 'package:klara/services/trash/trash_service.dart';

/// Valid 1×1 PNGs, decoded once: Uint8List equality is identity,
// so the assertions compare against these same instances.
final Uint8List _pngA = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

final Uint8List _pngB = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

MediaAsset _asset(String id) {
  return MediaAsset(
    id: id,
    type: MediaAssetType.image,
    width: 10,
    height: 10,
    sizeBytes: 1000,
    createDate: DateTime(2026, 10, 5),
    title: '$id.jpg',
    albumName: 'Camera',
  );
}

/// Bytes actually displayed by Image widgets (cacheWidth wraps
/// MemoryImage in a ResizeImage).
List<Uint8List> _shownBytes(WidgetTester tester) {
  return tester.widgetList<Image>(find.byType(Image)).map((Image image) {
    final ImageProvider provider = image.image;
    if (provider is ResizeImage) {
      return (provider.imageProvider as MemoryImage).bytes;
    }
    return (provider as MemoryImage).bytes;
  }).toList();
}

/// Media fake returning a distinct PNG per id.
class _Media implements MediaService {
  @override
  Future<Result<Uint8List>> getThumbnail(
    String assetId,
    int size, {
    int quality = 85,
  }) async {
    return Success<Uint8List>(assetId == 'a' ? _pngA : _pngB);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'not used by the keys test: ${invocation.memberName}',
  );
}

/// Local fake: session map + settings.
class _Local implements LocalService {
  final Map<String, DeckSession> sessions = <String, DeckSession>{};

  @override
  Future<Result<void>> saveSession(DeckSession session) async {
    sessions[session.filterKey] = session;
    return const Success<void>(null);
  }

  @override
  Future<Result<DeckSession?>> loadSession(String filterKey) async {
    return Success<DeckSession?>(sessions[filterKey]);
  }

  @override
  Future<Result<AppSettings>> loadSettings() async {
    return const Success<AppSettings>(AppSettings());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'not used by the keys test: ${invocation.memberName}',
  );
}

/// Trash fake: never called by these tests.
class _Trash implements TrashService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'not used by the keys test: ${invocation.memberName}',
  );
}

/// Trash fake serving a fixed record list.
class _TrashWithRecords implements TrashService {
  _TrashWithRecords(this.records);

  final List<TrashEntry> records;

  @override
  Future<Result<List<TrashEntry>>> listTrashed() async {
    return Success<List<TrashEntry>>(records);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'not used by the keys test: ${invocation.memberName}',
  );
}

TrashEntry _entry(String id, int size) {
  return TrashEntry(
    assetId: id,
    typeInt: 1,
    width: 10,
    height: 10,
    sizeBytes: size,
    trashedAt: DateTime(2026, 10, 25),
  );
}

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('unmarking the first review tile leaves the second photo', (
    WidgetTester tester,
  ) async {
    final ReviewController controller = ReviewController(
      media: _Media(),
      trash: _Trash(),
      local: _Local(),
      initialAssets: <MediaAsset>[_asset('a'), _asset('b')],
      filterKeyOverride: 'all',
    );
    Get.put<ReviewController>(controller);
    await tester.pumpWidget(
      GetMaterialApp(theme: AppTheme.light, home: const ReviewView()),
    );
    await tester.pumpAndSettle();
    expect(_shownBytes(tester), <Uint8List>[_pngA, _pngB]);

    await controller.unmark(_asset('a'));
    await tester.pumpAndSettle();
    expect(_shownBytes(tester), <Uint8List>[_pngB]);
  });

  testWidgets('removing the first trash row leaves the second row', (
    WidgetTester tester,
  ) async {
    final TrashController controller = TrashController(
      trash: _TrashWithRecords(<TrashEntry>[
        _entry('a', 1048576),
        _entry('b', 2097152),
      ]),
      local: _Local(),
    );
    Get.put<TrashController>(controller);
    await tester.pumpWidget(
      GetMaterialApp(theme: AppTheme.light, home: const TrashView()),
    );
    await tester.pumpAndSettle();
    expect(find.text(Formatters.formatBytes(1048576)), findsOneWidget);
    expect(find.text(Formatters.formatBytes(2097152)), findsOneWidget);

    controller.entries.removeAt(0);
    await tester.pumpAndSettle();
    expect(find.text(Formatters.formatBytes(1048576)), findsNothing);
    expect(find.text(Formatters.formatBytes(2097152)), findsOneWidget);
  });
}
