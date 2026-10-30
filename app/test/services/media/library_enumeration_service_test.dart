// Fix plan Stage 2 (ADR-017): the one-pass guarantees of the
// shared enumeration service, proven against a counting fake
// gateway — one call per media type per pass, a memoised pass
// for repeat readers, a shared in-flight pass for concurrent
// readers (the already-running guard), and no memoised failure.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:klara/core/utils/result.dart';
import 'package:klara/services/media/enumerated_asset.dart';
import 'package:klara/services/media/library_enumeration_service.dart';
import 'package:klara/services/media/library_enumeration_service_impl.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_enumeration_gateway.dart';

class _FakeGateway implements MediaEnumerationGateway {
  int imageCalls = 0;
  int videoCalls = 0;

  List<EnumeratedAsset> images = <EnumeratedAsset>[];
  List<EnumeratedAsset> videos = <EnumeratedAsset>[];

  /// When set, passes wait on this before returning (to hold a
  /// pass in flight) and the next pass throws once.
  Completer<void>? gate;
  bool throwNext = false;

  Future<List<EnumeratedAsset>> _run(
    List<EnumeratedAsset> rows,
    bool isImage,
  ) async {
    if (isImage) {
      imageCalls++;
    } else {
      videoCalls++;
    }
    if (throwNext) {
      throwNext = false;
      throw StateError('native query failed');
    }
    final Completer<void>? current = gate;
    if (current != null) {
      await current.future;
    }
    return rows;
  }

  @override
  Future<List<EnumeratedAsset>> enumerateImages() => _run(images, true);

  @override
  Future<List<EnumeratedAsset>> enumerateVideos() => _run(videos, false);
}

EnumeratedAsset _row(
  String id, {
  MediaAssetType type = MediaAssetType.image,
  String bucketId = '10',
  String bucketName = 'Camera',
  bool fileExists = true,
}) {
  return EnumeratedAsset(
    id: id,
    type: type,
    title: '$id.jpg',
    bucketId: bucketId,
    bucketName: bucketName,
    sizeBytes: 100,
    width: 10,
    height: 10,
    storeWidth: 10,
    storeHeight: 10,
    dateAddedSec: 1700000000,
    dateTakenMs: 0,
    dateModifiedSec: 1700000000,
    isFavorite: false,
    relativePath: 'DCIM/Camera',
    fileExists: fileExists,
  );
}

void main() {
  late _FakeGateway gateway;
  late LibraryEnumerationServiceImpl service;

  setUp(() {
    gateway = _FakeGateway();
    service = LibraryEnumerationServiceImpl(gateway: gateway);
  });

  test('one pass is exactly one call per media type', () async {
    gateway.images = <EnumeratedAsset>[_row('3'), _row('1')];
    gateway.videos = <EnumeratedAsset>[_row('2', type: MediaAssetType.video)];
    final Result<LibraryEnumeration> result = await service.enumerate();
    expect(result.isSuccess, isTrue);
    expect(gateway.imageCalls, 1);
    expect(gateway.videoCalls, 1);
    final LibraryEnumeration data =
        (result as Success<LibraryEnumeration>).value;
    // Merged newest first by MediaStore id, across both types.
    expect(data.rows.map((EnumeratedAsset r) => r.id).toList(), <String>[
      '3',
      '2',
      '1',
    ]);
  });

  test('a second reader is served from the memo — no new pass', () async {
    await service.enumerate();
    await service.enumerate();
    expect(gateway.imageCalls, 1);
    expect(gateway.videoCalls, 1);
  });

  test('forceRefresh runs a fresh pass and replaces the memo', () async {
    gateway.images = <EnumeratedAsset>[_row('1')];
    await service.enumerate();
    gateway.images = <EnumeratedAsset>[_row('9')];
    final Result<LibraryEnumeration> refreshed = await service.enumerate(
      forceRefresh: true,
    );
    expect(gateway.imageCalls, 2);
    expect(gateway.videoCalls, 2);
    final LibraryEnumeration data =
        (refreshed as Success<LibraryEnumeration>).value;
    expect(data.rows.map((EnumeratedAsset r) => r.id).toList(), <String>['9']);
    // The memo now holds the fresh pass.
    await service.enumerate();
    expect(gateway.imageCalls, 2);
  });

  test('concurrent readers share the single in-flight pass', () async {
    gateway.gate = Completer<void>();
    final Future<Result<LibraryEnumeration>> first = service.enumerate();
    final Future<Result<LibraryEnumeration>> second = service.enumerate(
      forceRefresh: true,
    );
    // Both gateway calls started exactly once despite two readers
    // (one of them forcing) arriving during the pass.
    expect(gateway.imageCalls, 1);
    expect(gateway.videoCalls, 1);
    gateway.gate!.complete();
    final Result<LibraryEnumeration> a = await first;
    final Result<LibraryEnumeration> b = await second;
    expect(a.isSuccess, isTrue);
    expect(b.isSuccess, isTrue);
    expect(gateway.imageCalls, 1);
    expect(gateway.videoCalls, 1);
  });

  test('a failed pass is never memoised — the next call retries', () async {
    gateway.throwNext = true;
    final Result<LibraryEnumeration> failed = await service.enumerate();
    expect(failed.isFailure, isTrue);
    final Result<LibraryEnumeration> retried = await service.enumerate();
    expect(retried.isSuccess, isTrue);
    expect(gateway.imageCalls, 2);
  });

  test('invalidate drops the memo', () async {
    await service.enumerate();
    service.invalidate();
    await service.enumerate();
    expect(gateway.imageCalls, 2);
    expect(gateway.videoCalls, 2);
  });

  test('a pass invalidated mid-flight does not memoise', () async {
    gateway.gate = Completer<void>();
    final Future<Result<LibraryEnumeration>> inFlight = service.enumerate();
    service.invalidate();
    gateway.gate!.complete();
    final Result<LibraryEnumeration> landed = await inFlight;
    expect(landed.isSuccess, isTrue);
    gateway.gate = null;
    await service.enumerate();
    // The landed pass answered its caller but was not memoised:
    // a fresh pass ran for the next reader.
    expect(gateway.imageCalls, 2);
  });

  test('bucket names cover buckets whose files are all gone', () async {
    gateway.images = <EnumeratedAsset>[
      _row('1', bucketId: '10', bucketName: 'Camera'),
      _row('2', bucketId: '20', bucketName: 'Ghosts', fileExists: false),
    ];
    final Result<LibraryEnumeration> result = await service.enumerate();
    final LibraryEnumeration data =
        (result as Success<LibraryEnumeration>).value;
    expect(data.bucketNames, <String, String>{'10': 'Camera', '20': 'Ghosts'});
    // Gone rows stay in the pass (asset lists filter them out).
    expect(data.rows.length, 2);
  });

  test('a library-change event invalidates the memo', () async {
    final StreamController<void> changes = StreamController<void>();
    final LibraryEnumerationServiceImpl watched = LibraryEnumerationServiceImpl(
      gateway: gateway,
      libraryChanged: changes.stream,
    );
    await watched.enumerate();
    expect(gateway.imageCalls, 1);
    changes.add(null);
    await Future<void>.delayed(Duration.zero);
    await watched.enumerate();
    expect(gateway.imageCalls, 2);
    watched.dispose();
    await changes.close();
  });
}
