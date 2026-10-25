import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:klara/core/strings/app_strings.dart';
import 'package:klara/core/theme/app_theme.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/features/review/controller/review_controller.dart';
import 'package:klara/features/review/widgets/review_bottom_bar.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_service.dart';
import 'package:klara/services/trash/trash_service.dart';

class _FakeMedia implements MediaService {
  @override
  Future<Result<Uint8List>> getThumbnail(
    String assetId,
    int size, {
    int quality = 85,
  }) async => Success<Uint8List>(Uint8List(0));

  @override
  Future<Result<List<MediaAsset>>> getAssetsByIds(List<String> ids) async {
    return const Success<List<MediaAsset>>(<MediaAsset>[]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeTrash implements TrashService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeLocal implements LocalService {
  @override
  Future<Result<AppSettings>> loadSettings() async =>
      const Success<AppSettings>(AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  tearDown(Get.reset);

  testWidgets('ReviewBottomBar renders Keep all and Delete buttons', (
    WidgetTester tester,
  ) async {
    final controller = ReviewController(
      media: _FakeMedia(),
      trash: _FakeTrash(),
      local: _FakeLocal(),
      initialAssets: <MediaAsset>[
        MediaAsset(
          id: '1',
          type: MediaAssetType.image,
          width: 10,
          height: 10,
          sizeBytes: 1000,
          createDate: DateTime.now(),
          title: 'test.jpg',
          albumName: 'Camera',
        ),
      ],
    );
    controller.onInit();

    bool deleted = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          bottomNavigationBar: ReviewBottomBar(
            controller: controller,
            onDelete: () => deleted = true,
          ),
        ),
      ),
    );

    expect(find.text(AppStrings.tr(AppStrings.actionKeepAll)), findsOneWidget);
    expect(find.text('Delete 1 photos'), findsOneWidget);

    await tester.tap(find.text('Delete 1 photos'));
    expect(deleted, isTrue);
  });
}
