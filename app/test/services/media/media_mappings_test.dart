import 'package:flutter_test/flutter_test.dart';
import 'package:klara/services/media/media_asset.dart';
import 'package:klara/services/media/media_service_impl.dart';
import 'package:photo_manager/photo_manager.dart';

void main() {
  group('mapPermissionState', () {
    test('authorized is full, limited stays limited, rest is denied', () {
      expect(
        mapPermissionState(PermissionState.authorized),
        MediaPermission.grantedFull,
      );
      expect(
        mapPermissionState(PermissionState.limited),
        MediaPermission.grantedLimited,
      );
      expect(
        mapPermissionState(PermissionState.denied),
        MediaPermission.denied,
      );
      expect(
        mapPermissionState(PermissionState.restricted),
        MediaPermission.denied,
      );
      expect(
        mapPermissionState(PermissionState.notDetermined),
        MediaPermission.denied,
      );
    });
  });

  group('mapFilterType', () {
    test('all/image/video map to common/image/video', () {
      expect(mapFilterType(MediaFilterType.all), RequestType.common);
      expect(mapFilterType(MediaFilterType.image), RequestType.image);
      expect(mapFilterType(MediaFilterType.video), RequestType.video);
    });
  });

  group('mapAssetType', () {
    test('image and video map; audio and other are skipped', () {
      expect(mapAssetType(AssetType.image), MediaAssetType.image);
      expect(mapAssetType(AssetType.video), MediaAssetType.video);
      expect(mapAssetType(AssetType.audio), isNull);
      expect(mapAssetType(AssetType.other), isNull);
    });
  });

  group('typeIntFor', () {
    test('image is 1 and video is 2 (AssetType index)', () {
      expect(typeIntFor(MediaAssetType.image), 1);
      expect(typeIntFor(MediaAssetType.video), 2);
    });
  });

  group('parseMonthKey', () {
    test('valid month gives half-open range', () {
      final ({DateTime start, DateTime end})? range = parseMonthKey('2026-10');
      expect(range?.start, DateTime(2026, 10));
      expect(range?.end, DateTime(2026, 11));
    });

    test('December rolls into January of the next year', () {
      final ({DateTime start, DateTime end})? range = parseMonthKey('2025-12');
      expect(range?.start, DateTime(2025, 12));
      expect(range?.end, DateTime(2026, 1));
    });

    test('invalid keys return null', () {
      expect(parseMonthKey('2026'), isNull);
      expect(parseMonthKey('2026-13'), isNull);
      expect(parseMonthKey('2026-00'), isNull);
      expect(parseMonthKey('oct-2026'), isNull);
      expect(parseMonthKey(''), isNull);
    });
  });
}
