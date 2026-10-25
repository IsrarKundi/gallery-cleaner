// Native library-change notifications (solutions 4.4).
//
// photo_manager delivers a callback when the device library
// changes (photo added, deleted, or edited in another app). The
// callback carries no asset ids — it is only a "something
// changed" flag, never photo content — so consumers reconcile
// cheaply on top of it (deck: page-0 refresh; hub/duplicates:
// dirty flag + re-scan on resume) instead of re-scanning blindly.
//
// Kept OFF the MediaService interface on purpose: adding a
// method there would break every test fake implementing it, and
// change delivery is a separate capability from media queries.
// The production implementation is constructed in InitialBinding
// and handed to the lifecycle service; controllers never touch
// photo_manager directly.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';

/// A stream of library-change flags, plus start/stop for the
/// native delivery. [start] enables delivery; [stop] disables it.
/// Implementations must deliver each native change exactly once.
abstract class LibraryChangeSource {
  /// Fires (with no payload) on every native library change.
  Stream<void> get onLibraryChanged;

  Future<void> start();

  Future<void> stop();
}

/// Production source over photo_manager's static change API.
/// [PhotoManager.notifyStream] is NOT the change event — it only
/// reports whether delivery is enabled — so this class subscribes
/// via [PhotoManager.addChangeCallback] and filters to the
/// 'change' method call.
class PhotoManagerChangeSource implements LibraryChangeSource {
  final StreamController<void> _controller = StreamController<void>.broadcast();

  bool _started = false;

  @override
  Stream<void> get onLibraryChanged => _controller.stream;

  @override
  Future<void> start() async {
    if (_started) {
      return;
    }
    PhotoManager.addChangeCallback(_onMethodCall);
    await PhotoManager.startChangeNotify();
    _started = true;
  }

  @override
  Future<void> stop() async {
    if (!_started) {
      return;
    }
    PhotoManager.removeChangeCallback(_onMethodCall);
    await PhotoManager.stopChangeNotify();
    _started = false;
  }

  void _onMethodCall(MethodCall call) {
    if (call.method == 'change') {
      _controller.add(null);
    }
  }
}
