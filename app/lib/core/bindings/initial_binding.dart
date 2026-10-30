import 'package:get/get.dart';

import '../../features/settings/controller/settings_controller.dart';
import '../../services/appinfo/app_info_service.dart';
import '../../services/appinfo/app_info_service_impl.dart';
import '../../services/detection/scan_repository.dart';
import '../../services/detection/scan_repository_impl.dart';
import '../../services/lifecycle/app_lifecycle.dart';
import '../../services/lifecycle/app_lifecycle_impl.dart';
import '../../services/media/library_change_source.dart';
import '../../services/local/local_service.dart';
import '../../services/local/local_service_db_impl.dart';
import '../../services/local/reminder_state_store.dart';
import '../../services/local/reminder_state_store_impl.dart';
import '../../services/media/library_enumeration_service.dart';
import '../../services/media/library_enumeration_service_impl.dart';
import '../../services/media/media_enumeration_gateway.dart';
import '../../services/media/video_frame_gateway.dart';
import '../../services/media/media_service.dart';
import '../../services/media/media_service_impl.dart';
import '../../services/notifications/notification_service.dart';
import '../../services/notifications/notification_service_impl.dart';
import '../../services/notifications/reminder_service.dart';
import '../../services/notifications/reminder_service_impl.dart';
import '../../services/local/review_ask_store.dart';
import '../../services/local/review_ask_store_impl.dart';
import '../../services/review_ask/review_ask_service.dart';
import '../../services/review_ask/review_ask_service_impl.dart';
import '../../services/review_ask/review_gateway.dart';
import '../../services/review_ask/review_gateway_impl.dart';
import '../../services/share/share_service.dart';
import '../../services/share/share_service_impl.dart';
import '../../services/storage/storage_service.dart';
import '../../services/storage/storage_service_impl.dart';
import '../../services/trash/trash_gateway_impl.dart';
import '../../services/video/video_compression_service.dart';
import '../../services/video/video_compression_service_impl.dart';
import '../../services/trash/trash_service.dart';
import '../../services/trash/trash_service_impl.dart';
import '../../services/thumbnail/thumbnail_service.dart';
import '../../services/thumbnail/thumbnail_service_impl.dart';
import '../../services/warmup/deck_warm_up.dart';
import '../../services/warmup/deck_warm_up_impl.dart';

/// The ONLY place global Get.put lives (AGENTS.md).
///
/// Services registered behind their interfaces so controllers depend
/// on abstractions, never implementations. Order matters:
/// [TrashServiceImpl] takes [LocalService], so the local service is
/// registered first. Phase 1.7: only Local, Media, Trash and the
/// [SettingsController] are eager permanent. Video, Storage, Share,
/// Notification and AppInfo are lazy (fenix: re-created if ever
/// removed) so launch does not construct plugin objects the first
/// screen never touches; each is created on its first find (video at
/// the compress screen, storage at the hub, share at the deck,
/// notification on the first nudge toggle, app-info on the first
/// settings-screen version read). Phase 3A adds the permanent
/// [SettingsController], whose onInit applies the persisted theme,
/// haptics and (via main.dart's builder) reduced-motion at launch.
class InitialBinding extends Bindings {
  @override
  void dependencies() {
    // Phase 6.3: the database implementation serves LocalService.
    // First launch migrates the JSON files once (see
    // json_migration.dart); fresh installs start empty. Settings
    // still reads JSON through the same implementation.
    Get.put<LocalService>(LocalServiceDbImpl(), permanent: true);
    // Phase 4.4: the single foreground/background observer.
    // Permanent: controllers register listeners in onInit and
    // unregister in onClose. Constructed (not lazy) so attach()
    // registers the observer at launch; pause flushes pending
    // session writes centrally (see app_lifecycle_impl.dart).
    // The change source is best-effort: if native delivery
    // fails to start, consumers fall back to resume-time
    // refresh and this stream simply never emits.
    // (Constructed before the media service since fix plan
    // Stage 2: the enumeration below invalidates on the same
    // library-change stream the deck and hub reconcile on.)
    final AppLifecycleImpl lifecycle = AppLifecycleImpl(
      local: Get.find<LocalService>(),
      changeSource: PhotoManagerChangeSource(),
    );
    lifecycle.attach();
    Get.put<AppLifecycle>(lifecycle, permanent: true);
    // Fix plan Stage 2 (ADR-017): the one-pass library
    // enumeration — one native MediaStore query per media type,
    // memoised and shared. The media service serves its pages
    // and id lookups from it; the shared scan forces one fresh
    // pass per run. Not registered behind Get: it is a
    // capability of the media layer, handed to its two
    // consumers directly (the LibraryChangeSource precedent).
    final LibraryEnumerationService enumeration = LibraryEnumerationServiceImpl(
      gateway: NativeMediaEnumerationGateway(),
      libraryChanged: lifecycle.libraryChanged,
    );
    Get.put<MediaService>(
      MediaServiceImpl(enumeration: enumeration),
      permanent: true,
    );
    // Phase 2.3: the single shared thumbnail cache for the app.
    // Controllers receive it through their bindings; the deck
    // warm-up does not need it (it warms the page, not bytes).
    Get.put<ThumbnailService>(
      ThumbnailServiceImpl(media: Get.find<MediaService>()),
      permanent: true,
    );
    // Phase 2.2: permanent warm-up for the deck's critical path.
    // Started by the splash binding; the deck joins it on first init.
    Get.put<DeckWarmUp>(
      DeckWarmUpImpl(media: Get.find<MediaService>()),
      permanent: true,
    );
    // Phase 4.2: the single shared library scan for the hub,
    // Duplicates, and smart-deck entry. Permanent so a scan
    // survives controller lifetimes (see scan_repository.dart).
    Get.put<ScanRepository>(
      ScanRepositoryImpl(
        media: Get.find<MediaService>(),
        local: Get.find<LocalService>(),
        enumeration: enumeration,
        // Fix plan Stage 6 (ADR-021): the scan's video pass
        // reads frames through wipe.'s own native frame
        // channel — same hand-it-directly pattern as the
        // enumeration above.
        videoFrames: const NativeVideoFrameGateway(),
      ),
      permanent: true,
    );
    Get.lazyPut<VideoCompressionService>(
      VideoCompressionServiceImpl.new,
      fenix: true,
    );
    Get.lazyPut<StorageService>(StorageServiceImpl.new, fenix: true);
    Get.lazyPut<ShareService>(ShareServiceImpl.new, fenix: true);
    Get.lazyPut<NotificationService>(NotificationServiceImpl.new, fenix: true);
    // Fix plan Stage 1: the state-reminder engine, lazy for the
    // same reason as the notification service — it is built on
    // first use (the splash binding resolves it at launch, the
    // Settings toggle after a flip), never during this binding.
    // Its constructor only wires dependencies and a pause
    // listener; all plugin work waits for refresh().
    Get.lazyPut<ReminderStateStore>(ReminderStateStoreImpl.new, fenix: true);
    Get.lazyPut<ReminderService>(
      () => ReminderServiceImpl(
        local: Get.find<LocalService>(),
        media: Get.find<MediaService>(),
        notifications: Get.find<NotificationService>(),
        reminderStore: Get.find<ReminderStateStore>(),
        lifecycle: Get.find<AppLifecycle>(),
      ),
      fenix: true,
    );
    // Fix plan Stage 5 (ADR-020): the review-ask service, lazy
    // like the reminder engine — built on first use (deck /
    // smart-deck / review bindings resolve it when present),
    // never during this binding. Its constructor only wires
    // dependencies; the store file is first read by an event.
    Get.lazyPut<ReviewAskStore>(ReviewAskStoreImpl.new, fenix: true);
    Get.lazyPut<ReviewGateway>(ReviewGatewayImpl.new, fenix: true);
    Get.lazyPut<ReviewAskService>(
      () => ReviewAskServiceImpl(
        local: Get.find<LocalService>(),
        store: Get.find<ReviewAskStore>(),
        gateway: Get.find<ReviewGateway>(),
        share: Get.find<ShareService>(),
      ),
      fenix: true,
    );
    Get.lazyPut<AppInfoService>(AppInfoServiceImpl.new, fenix: true);
    Get.put<TrashService>(
      TrashServiceImpl(
        gateway: TrashGatewayImpl(),
        local: Get.find<LocalService>(),
      ),
      permanent: true,
    );
    // Built WITHOUT the notification and app-info services on
    // purpose: finding them here would create them at launch and
    // defeat the lazy registrations above. The controller resolves
    // them lazily on first use instead (see SettingsController
    // ._notifications / ._appInfo). The /settings binding reuses
    // this instance (it does not create a second controller).
    Get.put<SettingsController>(
      SettingsController(local: Get.find<LocalService>()),
      permanent: true,
    );
  }
}
