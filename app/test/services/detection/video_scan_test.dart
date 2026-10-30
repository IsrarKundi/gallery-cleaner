// Stage 6 scanner integration (fix plan Stage 6, ADR-021):
// the video pass inside the shared scan — gate enforcement,
// grouping into the SAVED memberships, unreadable videos,
// cancellation, and the freshness short-circuit (a fresh
// snapshot never touches the frame gateway). Fakes only; the
// frame gateway is the seam the native channel sits behind in
// production.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:klara/core/utils/result.dart';
import 'package:klara/services/detection/analysis_worker.dart';
import 'package:klara/services/detection/library_scanner.dart';
import 'package:klara/services/detection/photo_assessment.dart';
import 'package:klara/services/detection/scan_memberships.dart';
import 'package:klara/services/detection/thumbnail_analysis.dart';
import 'package:klara/services/detection/video_scan_pass.dart';
import 'package:klara/services/detection/video_similarity.dart';
import 'package:klara/services/local/local_service_impl.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_service.dart';
import 'package:klara/services/media/video_frame_gateway.dart';

/// A 9x8 grayscale PNG whose every row is [values] — the
/// frame stand-in. The ramps are chosen so their dHashes are
/// known exactly (see the precondition test): x = all-zero
/// bits, y = alternating bits from position 1, z = from
/// position 0, w = paired bits (0xCC per row) — every pair of
/// distinct ramps sits at Hamming distance >= 32, so frames
/// from different ramps never match, however often the cycle
/// repeats them across a video's sampled timestamps.
Uint8List _framePng(List<int> values) {
  final img.Image image = img.Image(width: 9, height: 8);
  for (int row = 0; row < 8; row++) {
    for (int x = 0; x < 9; x++) {
      final int v = values[x];
      image.setPixelRgb(x, row, v, v, v);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

final Uint8List _x = _framePng(<int>[0, 32, 64, 96, 128, 160, 192, 224, 255]);
final Uint8List _y = _framePng(<int>[0, 100, 50, 150, 100, 200, 150, 250, 200]);
final Uint8List _z = _framePng(<int>[
  250,
  200,
  210,
  150,
  160,
  100,
  110,
  50,
  60,
]);
final Uint8List _w = _framePng(<int>[0, 50, 100, 90, 80, 130, 180, 170, 160]);

MediaAsset _video(
  String id, {
  int sizeBytes = 10 * 1024 * 1024,
  DateTime? createDate,
}) {
  return MediaAsset(
    id: id,
    type: MediaAssetType.video,
    width: 640,
    height: 360,
    sizeBytes: sizeBytes,
    createDate: createDate ?? DateTime.utc(2026, 1, 1),
    title: id,
    albumName: 'all',
  );
}

MediaAsset _image(String id) {
  return MediaAsset(
    id: id,
    type: MediaAssetType.image,
    width: 100,
    height: 100,
    sizeBytes: 1000,
    createDate: DateTime.utc(2026, 1, 1),
    title: id,
    albumName: 'all',
  );
}

class _FakeMedia implements MediaService {
  _FakeMedia({required this.pages});

  final List<List<MediaAsset>> pages;

  @override
  Future<Result<MediaPermission>> requestPermission() {
    throw UnimplementedError();
  }

  @override
  Future<Result<void>> presentLimitedSelection() {
    throw UnimplementedError();
  }

  @override
  Future<Result<void>> openAppSettings() {
    throw UnimplementedError();
  }

  @override
  Future<Result<List<MediaAlbum>>> getAlbums() async {
    return const Success<List<MediaAlbum>>(<MediaAlbum>[]);
  }

  @override
  Future<Result<List<MediaAsset>>> getAssets({
    String? albumId,
    String? monthKey,
    MediaFilterType type = MediaFilterType.all,
    int page = 0,
    int pageSize = 50,
  }) async {
    if (page < pages.length) {
      return Success<List<MediaAsset>>(pages[page]);
    }
    return const Success<List<MediaAsset>>(<MediaAsset>[]);
  }

  @override
  Future<Result<List<MediaAsset>>> getAssetsByIds(List<String> ids) {
    throw UnimplementedError();
  }

  @override
  Future<Result<Uint8List>> getThumbnail(
    String assetId,
    int size, {
    int quality = 85,
  }) async {
    // Any decodable bytes: photo phases only need the image
    // asset to fingerprint/blur without error.
    return Success<Uint8List>(_x);
  }
}

class _FakeGateway implements VideoFrameGateway {
  _FakeGateway({required this.framesById, this.durations = const {}});

  /// Frame PNGs cycled across the requested timestamps.
  final Map<String, List<Uint8List>> framesById;

  /// Duration overrides; ids absent here read as 20 s, a null
  /// value (present key) reads as unreadable.
  final Map<String, Duration?> durations;

  final List<String> durationAsked = <String>[];
  final List<String> framesAsked = <String>[];

  /// Hook fired inside [videoDuration] (the cancellation test
  /// flips the scan's cancel flag here).
  void Function(String assetId)? onDuration;

  @override
  Future<Duration?> videoDuration(String assetId) async {
    durationAsked.add(assetId);
    onDuration?.call(assetId);
    if (durations.containsKey(assetId)) {
      return durations[assetId];
    }
    return const Duration(seconds: 20);
  }

  @override
  Future<List<Uint8List?>> extractFrames(
    String assetId,
    List<Duration> timestamps,
  ) async {
    framesAsked.add(assetId);
    final List<Uint8List> cycle = framesById[assetId] ?? const <Uint8List>[];
    return <Uint8List?>[
      for (int i = 0; i < timestamps.length; i++)
        cycle.isEmpty ? null : cycle[i % cycle.length],
    ];
  }
}

/// The sync fingerprint batch dressed as the async runner the
/// pass expects (deterministic in tests; production spawns the
/// isolate variant).
Future<List<FingerprintComputation?>> _syncBatch(
  List<AnalysisBatchInput> inputs,
) async {
  return fingerprintBatchSync(inputs);
}

class _CountingLocal extends LocalServiceImpl {
  _CountingLocal({required Directory directory})
    : super(directoryResolver: () async => directory);

  int saveMembershipsCalls = 0;

  @override
  Future<Result<void>> saveScanMemberships(ScanMemberships memberships) {
    saveMembershipsCalls++;
    return super.saveScanMemberships(memberships);
  }
}

void main() {
  late Directory temp;
  late _CountingLocal local;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('klara_stage6_scan_test_');
    local = _CountingLocal(directory: temp);
  });

  tearDown(() async {
    await local.dispose();
    if (await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  test('frame stand-ins behave as the scenarios need (preconditions)', () {
    PhotoFingerprint printOf(Uint8List png) =>
        computeFingerprint(png)!.fingerprint;
    final List<PhotoFingerprint> pair = <PhotoFingerprint>[
      printOf(_x),
      printOf(_y),
    ];
    final List<PhotoFingerprint> other = <PhotoFingerprint>[
      printOf(_z),
      printOf(_w),
    ];
    // Identical lists match fully; the other pair shares no
    // matching frame at all (every cross-ramp pair is at
    // Hamming >= 32 — see _framePng's doc).
    expect(videosAreSimilar(pair, pair), isTrue);
    expect(countMatchingFrames(pair, other), 0);
    expect(videosAreSimilar(pair, other), isFalse);
  });

  group('video pass in the scan', () {
    _FakeGateway gateway() {
      return _FakeGateway(
        framesById: <String, List<Uint8List>>{
          'v1': <Uint8List>[_x, _y],
          'v2': <Uint8List>[_x, _y],
          'v3': <Uint8List>[_z, _w],
        },
      );
    }

    LibraryScanner scanner(_FakeMedia media, _FakeGateway gw) {
      return LibraryScanner(
        media: media,
        local: local,
        videoPass: VideoScanPass(gateway: gw, fingerprintBatch: _syncBatch),
      );
    }

    test('groups similar videos into the saved memberships; the '
        'gate keeps big videos and images away from the gateway', () async {
      final _FakeGateway gw = gateway();
      final _FakeMedia media = _FakeMedia(
        pages: <List<MediaAsset>>[
          <MediaAsset>[
            _video('v1', createDate: DateTime.utc(2026, 1, 1)),
            _video('v2', createDate: DateTime.utc(2026, 1, 2)),
            _video('v3', createDate: DateTime.utc(2026, 1, 3)),
            _video(
              'vBig',
              sizeBytes: maxSimilarVideoBytes + 1,
              createDate: DateTime.utc(2026, 1, 4),
            ),
            _image('a1'),
          ],
        ],
      );
      final LibraryScan result = await scanner(media, gw).scan();
      expect(result.cancelled, isFalse);
      expect(result.pageFailed, isFalse);
      final List<ScanGroup> groups = result.memberships.groupsOfKind(
        ScanGroupKind.similarVideos,
      );
      expect(groups.length, 1);
      expect(groups.single.memberIds, <String>['v1', 'v2']);
      expect(groups.single.seedId, 'v1');
      expect(groups.single.keeperId, isNull);
      // The gate: vBig was never asked anything; the image
      // never reached the gateway either.
      expect(gw.durationAsked, <String>['v1', 'v2', 'v3']);
      expect(gw.framesAsked, <String>['v1', 'v2', 'v3']);
      // And the group is in the PERSISTED snapshot, not just
      // the run's result.
      final Result<ScanMemberships> saved = await local.loadScanMemberships();
      final ScanMemberships back = saved.fold(
        onSuccess: (ScanMemberships v) => v,
        onFailure: (_) => throw StateError('load failed'),
      );
      expect(back.groupsOfKind(ScanGroupKind.similarVideos).length, 1);
      expect(back.allMemberIdsOf(ScanGroupKind.similarVideos), <String>{
        'v1',
        'v2',
      });
    });

    test('no gateway wired: the scan completes with no video groups', () async {
      final _FakeMedia media = _FakeMedia(
        pages: <List<MediaAsset>>[
          <MediaAsset>[_video('v1'), _video('v2')],
        ],
      );
      final LibraryScanner plain = LibraryScanner(media: media, local: local);
      final LibraryScan result = await plain.scan();
      expect(result.cancelled, isFalse);
      expect(
        result.memberships.groupsOfKind(ScanGroupKind.similarVideos),
        isEmpty,
      );
    });

    test('an unreadable video is skipped; the pair still groups', () async {
      final _FakeGateway gw = _FakeGateway(
        framesById: <String, List<Uint8List>>{
          'v1': <Uint8List>[_x, _y],
          'v2': <Uint8List>[_x, _y],
        },
        durations: <String, Duration?>{'vBad': null},
      );
      final _FakeMedia media = _FakeMedia(
        pages: <List<MediaAsset>>[
          <MediaAsset>[
            _video('vBad', createDate: DateTime.utc(2025, 12, 31)),
            _video('v1', createDate: DateTime.utc(2026, 1, 1)),
            _video('v2', createDate: DateTime.utc(2026, 1, 2)),
          ],
        ],
      );
      final LibraryScan result = await scanner(media, gw).scan();
      expect(result.cancelled, isFalse);
      final List<ScanGroup> groups = result.memberships.groupsOfKind(
        ScanGroupKind.similarVideos,
      );
      expect(groups.length, 1);
      expect(groups.single.memberIds, <String>['v1', 'v2']);
      // The unreadable video was asked for a duration (that is
      // how the scan learns it is unreadable) but never for
      // frames.
      expect(gw.durationAsked, contains('vBad'));
      expect(gw.framesAsked, isNot(contains('vBad')));
    });

    test('cancellation during the video pass persists nothing', () async {
      bool cancel = false;
      final _FakeGateway gw = gateway();
      gw.onDuration = (String id) {
        if (id == 'v2') {
          cancel = true;
        }
      };
      final _FakeMedia media = _FakeMedia(
        pages: <List<MediaAsset>>[
          <MediaAsset>[
            _video('v1', createDate: DateTime.utc(2026, 1, 1)),
            _video('v2', createDate: DateTime.utc(2026, 1, 2)),
            _video('v3', createDate: DateTime.utc(2026, 1, 3)),
          ],
        ],
      );
      final LibraryScan result = await scanner(
        media,
        gw,
      ).scan(isCancelled: () => cancel);
      expect(result.cancelled, isTrue);
      expect(local.saveMembershipsCalls, 0);
    });

    test('a fresh snapshot is reused: the second scan never '
        'touches the gateway', () async {
      final _FakeGateway gw = gateway();
      final List<MediaAsset> page = <MediaAsset>[
        _video('v1', createDate: DateTime.utc(2026, 1, 1)),
        _video('v2', createDate: DateTime.utc(2026, 1, 2)),
        _video('v3', createDate: DateTime.utc(2026, 1, 3)),
      ];
      final _FakeMedia media = _FakeMedia(pages: <List<MediaAsset>>[page]);
      final LibraryScan first = await scanner(media, gw).scan();
      expect(
        first.memberships.groupsOfKind(ScanGroupKind.similarVideos).length,
        1,
      );
      expect(gw.durationAsked.length, 3);
      final LibraryScan second = await scanner(media, gw).scan();
      expect(second.cancelled, isFalse);
      final List<ScanGroup> reused = second.memberships.groupsOfKind(
        ScanGroupKind.similarVideos,
      );
      expect(reused.length, 1);
      expect(reused.single.memberIds, <String>['v1', 'v2']);
      // Unchanged library + current version: no duration reads,
      // no frame extraction, no re-save.
      expect(gw.durationAsked.length, 3);
      expect(gw.framesAsked.length, 3);
      expect(local.saveMembershipsCalls, 1);
    });
  });

  group('membership shape for the new kind', () {
    test('JSON round-trips a similarVideos group; no hash keys', () {
      final ScanMemberships snapshot = ScanMemberships(
        algorithmVersion: scanMembershipAlgorithmVersion,
        assetInfos: const <String, AssetInfo>{},
        groups: const <ScanGroup>[
          ScanGroup(
            kind: ScanGroupKind.similarVideos,
            memberIds: <String>['v1', 'v2'],
            seedId: 'v1',
          ),
        ],
        duplicateReferences: const <DuplicateReference>[],
      );
      final ScanMemberships back = ScanMemberships.fromJson(snapshot.toJson());
      expect(back.groups.single.kind, ScanGroupKind.similarVideos);
      expect(back.groups.single.memberIds, <String>['v1', 'v2']);
      expect(back.groups.single.seedId, 'v1');
      expect(back.groups.single.keeperId, isNull);
      expect(back.allMemberIdsOf(ScanGroupKind.similarVideos), <String>{
        'v1',
        'v2',
      });
    });

    test('a version 1 snapshot is never fresh at version 2', () {
      final Map<String, AssetInfo> facts = <String, AssetInfo>{
        'v1': const AssetInfo(
          assetId: 'v1',
          type: MediaAssetType.video,
          width: 640,
          height: 360,
          sizeBytes: 5000,
          modifiedDateMs: null,
          isEdited: false,
          isScreenshot: false,
        ),
      };
      final ScanMemberships v1 = ScanMemberships(
        algorithmVersion: 1,
        assetInfos: facts,
        groups: const <ScanGroup>[],
        duplicateReferences: const <DuplicateReference>[],
      );
      expect(v1.isFreshFor(facts), isFalse);
      final ScanMemberships v2 = ScanMemberships(
        algorithmVersion: scanMembershipAlgorithmVersion,
        assetInfos: facts,
        groups: const <ScanGroup>[],
        duplicateReferences: const <DuplicateReference>[],
      );
      expect(v2.isFreshFor(facts), isTrue);
    });
  });
}
