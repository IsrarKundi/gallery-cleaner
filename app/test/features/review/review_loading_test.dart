// Per-action loading on the Review bottom bar (owner report
// 30 Oct 2026): pressing Delete made BOTH bottom buttons spin,
// and the spinner could outlive the action forever.
//
// These tests pin the professional contract:
// - each action spins ONLY its own button;
// - while one action runs, the other button is disabled (not
//   spinning, not tappable) and the running button cannot be
//   re-tapped;
// - loading clears on EVERY outcome — success, denied, service
//   failure, and a thrown exception mid-action.
//
// The fakes gate the async boundaries with [Completer]s so an
// action can be held pending while the bar's state is asserted.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:klara/core/theme/app_theme.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/core/widgets/primary_button.dart';
import 'package:klara/core/widgets/secondary_button.dart';
import 'package:klara/features/review/controller/review_controller.dart';
import 'package:klara/features/review/widgets/review_bottom_bar.dart';
import 'package:klara/services/local/local_service.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_service.dart';
import 'package:klara/services/trash/trash_service.dart';

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

class _GatedTrash implements TrashService {
  Completer<Result<DeleteOutcome>>? deleteGate;
  Result<DeleteOutcome>? deleteResult;
  int deleteCalls = 0;

  @override
  Future<Result<DeleteOutcome>> deletePermanently(List<String> ids) {
    deleteCalls++;
    final Completer<Result<DeleteOutcome>>? gate = deleteGate;
    if (gate != null) {
      return gate.future;
    }
    return Future<Result<DeleteOutcome>>.value(
      deleteResult ??
          Success<DeleteOutcome>(
            DeleteOutcome(
              deletedIds: List<String>.of(ids),
              deniedIds: const <String>[],
              failedIds: const <String>[],
            ),
          ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _GatedLocal implements LocalService {
  bool throwOnLoadSettings = false;
  Completer<Result<void>>? saveGate;
  bool failSave = false;

  @override
  Future<Result<AppSettings>> loadSettings() async {
    if (throwOnLoadSettings) {
      throw StateError('settings store exploded');
    }
    return const Success<AppSettings>(AppSettings());
  }

  @override
  Future<Result<DeckSession?>> loadSession(String filterKey) async {
    return const Success<DeckSession?>(null);
  }

  @override
  Future<Result<void>> saveSession(DeckSession session) {
    final Completer<Result<void>>? gate = saveGate;
    if (gate != null) {
      return gate.future;
    }
    if (failSave) {
      return Future<Result<void>>.value(
        const Failure<void>(AppFailure(messageKey: 'errorLocal')),
      );
    }
    return Future<Result<void>>.value(const Success<void>(null));
  }

  @override
  Future<Result<void>> appendHistory(HistoryRecord record) async {
    return const Success<void>(null);
  }

  @override
  Future<Result<List<DeckSession>>> listSessions() async {
    return const Success<List<DeckSession>>(<DeckSession>[]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ReviewController _controller({
  required _GatedTrash trash,
  required _GatedLocal local,
  int assetCount = 2,
}) {
  final ReviewController controller = ReviewController(
    media: _FakeMedia(),
    trash: trash,
    local: local,
    initialAssets: <MediaAsset>[
      for (int i = 1; i <= assetCount; i++) _asset('$i'),
    ],
  );
  controller.onInit();
  return controller;
}

Future<void> _pumpBar(WidgetTester tester, ReviewController controller) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        bottomNavigationBar: ReviewBottomBar(
          controller: controller,
          onDelete: () => controller.deleteSelected(
            onlyIds: controller.hasSelection
                ? controller.selectedItems.map((a) => a.id).toList()
                : null,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Finder _spinnerIn(Type ancestor) {
  return find.descendant(
    of: find.byType(ancestor),
    matching: find.byType(CircularProgressIndicator),
  );
}

void main() {
  tearDown(Get.reset);

  testWidgets('delete pending: only Delete spins, Keep disabled', (
    WidgetTester tester,
  ) async {
    final _GatedTrash trash = _GatedTrash();
    final _GatedLocal local = _GatedLocal();
    trash.deleteGate = Completer<Result<DeleteOutcome>>();
    final ReviewController controller = _controller(trash: trash, local: local);
    await _pumpBar(tester, controller);

    await tester.tap(find.byType(PrimaryButton));
    await tester.pump();
    await tester.pump();

    // Exactly one spinner, and it belongs to Delete.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(_spinnerIn(PrimaryButton), findsOneWidget);
    expect(_spinnerIn(SecondaryButton), findsNothing);
    // Keep is disabled (not tappable) while Delete runs, and the
    // running Delete button cannot be re-tapped.
    final OutlinedButton keepButton = tester.widget<OutlinedButton>(
      find.byType(OutlinedButton),
    );
    expect(keepButton.onPressed, isNull);
    final FilledButton deleteButton = tester.widget<FilledButton>(
      find.byType(FilledButton),
    );
    expect(deleteButton.onPressed, isNull);

    // Success clears the loading state completely.
    trash.deleteGate!.complete(
      const Success<DeleteOutcome>(
        DeleteOutcome(
          deletedIds: <String>['1', '2'],
          deniedIds: <String>[],
          failedIds: <String>[],
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(controller.isDeleting.value, isFalse);
  });

  testWidgets('keep pending: only Keep spins, Delete disabled; '
      'failure clears', (WidgetTester tester) async {
    final _GatedTrash trash = _GatedTrash();
    final _GatedLocal local = _GatedLocal();
    local.saveGate = Completer<Result<void>>();
    final ReviewController controller = _controller(trash: trash, local: local);
    await _pumpBar(tester, controller);

    await tester.tap(find.byType(SecondaryButton));
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(_spinnerIn(SecondaryButton), findsOneWidget);
    expect(_spinnerIn(PrimaryButton), findsNothing);
    final FilledButton deleteButton = tester.widget<FilledButton>(
      find.byType(FilledButton),
    );
    expect(deleteButton.onPressed, isNull);
    final OutlinedButton keepButton = tester.widget<OutlinedButton>(
      find.byType(OutlinedButton),
    );
    expect(keepButton.onPressed, isNull);

    // A failed session write ends the action: spinner gone.
    local.saveGate!.complete(
      const Failure<void>(AppFailure(messageKey: 'errorLocal')),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(controller.items.length, 2);
  });

  testWidgets('selection mode: keep-selected pending spins only Keep; '
      'success clears and keeps the rest', (WidgetTester tester) async {
    final _GatedTrash trash = _GatedTrash();
    final _GatedLocal local = _GatedLocal();
    final ReviewController controller = _controller(trash: trash, local: local);
    controller.selection.selectAll(<String>['1']);
    local.saveGate = Completer<Result<void>>();
    await _pumpBar(tester, controller);

    await tester.tap(find.byType(SecondaryButton));
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(_spinnerIn(SecondaryButton), findsOneWidget);
    expect(_spinnerIn(PrimaryButton), findsNothing);

    local.saveGate!.complete(const Success<void>(null));
    await tester.pump();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    // The kept photo left the grid; the unselected one stays.
    expect(
      controller.items.map((MediaAsset a) => a.id),
      containsAll(<String>['2']),
    );
    expect(controller.items.length, 1);
  });

  test('delete clears loading on denied and on service failure', () async {
    final _GatedTrash trash = _GatedTrash();
    final _GatedLocal local = _GatedLocal();
    final ReviewController controller = _controller(trash: trash, local: local);

    trash.deleteResult = const Success<DeleteOutcome>(
      DeleteOutcome(
        deletedIds: <String>[],
        deniedIds: <String>['1', '2'],
        failedIds: <String>[],
      ),
    );
    final ReviewDeleteOutcome? denied = await controller.deleteSelected();
    expect(denied, ReviewDeleteOutcome.denied);
    expect(controller.isDeleting.value, isFalse);

    trash.deleteResult = const Failure<DeleteOutcome>(
      AppFailure(messageKey: 'errorTrash'),
    );
    final ReviewDeleteOutcome? failed = await controller.deleteSelected();
    expect(failed, ReviewDeleteOutcome.serviceError);
    expect(controller.isDeleting.value, isFalse);
  });

  test('a thrown exception mid-delete still clears loading, and the '
      'next delete is not swallowed', () async {
    final _GatedTrash trash = _GatedTrash();
    final _GatedLocal local = _GatedLocal();
    final ReviewController controller = _controller(trash: trash, local: local);

    local.throwOnLoadSettings = true;
    await expectLater(controller.deleteSelected(), throwsA(isA<StateError>()));
    expect(controller.isDeleting.value, isFalse);

    // The stuck-flag guard must not eat later actions.
    local.throwOnLoadSettings = false;
    final ReviewDeleteOutcome? outcome = await controller.deleteSelected();
    expect(outcome, ReviewDeleteOutcome.deleted);
    expect(controller.isDeleting.value, isFalse);
  });
}
