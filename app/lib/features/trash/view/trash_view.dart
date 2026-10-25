import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_banner.dart';
import '../../../core/widgets/error_view.dart';
import '../controller/trash_controller.dart';
import '../widgets/trash_bottom_bar.dart';
import '../widgets/trash_loading_skeleton.dart';
import '../widgets/trash_row.dart';

/// Trash screen (requirements §4): the recorded Trash list, restore
/// single + multi, and emptying. Layout + Obx only: the native-sheet
/// outcomes and history writes live in [TrashController].
///
/// Navigation contract (see the controller): every exit resets the
/// stack with [Get.offAllNamed] — the AppBar back control, the system
/// back gesture (via [PopScope]) and the empty-state CTA all go to
/// the deck, never [Get.back] into a stale deck controller.
/// Emptying is destructive, so it first shows Klara's own in-app
/// confirmation (stating the deletion cannot be undone — the only
/// place that wording is allowed, because after emptying restore no
/// longer exists) and only then the native sheet.
class TrashView extends GetView<TrashController> {
  const TrashView({super.key});

  Future<void> _restore(BuildContext context, List<String> ids) async {
    final TrashActionOutcome? outcome = await controller.restore(ids);
    if (!context.mounted) {
      return;
    }
    switch (outcome) {
      case TrashActionOutcome.restored:
        AppSnackbar.show(
          context,
          message: ids.length == 1
              ? AppStrings.tr(AppStrings.snackRestored)
              : AppStrings.tr(AppStrings.snackRestoredMany, <String, String>{
                  'count': '${ids.length}',
                }),
        );
      case TrashActionOutcome.denied:
        // Phase 3B: a denied restore that also restored some photos
        // used to report only the denial. Count the restored part.
        await AppDialog.showConfirmation(
          context,
          title: AppStrings.tr(AppStrings.deniedConfirmTitle),
          message: controller.lastRestoredCount.value > 0
              ? AppStrings.tr(
                  AppStrings.trashRestoreDeniedMixed,
                  <String, String>{
                    'restored': '${controller.lastRestoredCount.value}',
                  },
                )
              : AppStrings.tr(AppStrings.trashDeniedMessage),
          confirmLabel: AppStrings.tr(AppStrings.actionOk),
        );
      case TrashActionOutcome.failed:
      case TrashActionOutcome.serviceError:
      case TrashActionOutcome.emptied:
      case null:
        // Failed / service errors render in the inline error strip.
        break;
    }
  }

  Future<void> _emptyTrash(BuildContext context) async {
    final bool confirmed = await AppDialog.showConfirmation(
      context,
      title: AppStrings.tr(AppStrings.trashEmptyConfirmTitle),
      message: AppStrings.tr(AppStrings.trashEmptyConfirmMessage),
      confirmLabel: AppStrings.tr(AppStrings.trashEmpty),
      cancelLabel: AppStrings.tr(AppStrings.actionCancel),
      isDestructive: true,
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    final TrashActionOutcome? outcome = await controller.emptyTrash();
    if (!context.mounted) {
      return;
    }
    switch (outcome) {
      case TrashActionOutcome.emptied:
        AppSnackbar.show(
          context,
          message: AppStrings.tr(AppStrings.snackTrashEmptied, <String, String>{
            'size': Formatters.formatBytes(controller.lastFreedBytes.value),
          }),
        );
      case TrashActionOutcome.denied:
        // Phase 3B: a denied emptying that also removed some photos
        // used to report only the denial (and swallow the freed
        // figure). Count the removed part; no history is written
        // for a denied run beyond what emptyTrash already recorded
        // for the removed ids.
        await AppDialog.showConfirmation(
          context,
          title: AppStrings.tr(AppStrings.deniedConfirmTitle),
          message: controller.lastFreedBytes.value > 0
              ? AppStrings.tr(
                  AppStrings.trashEmptyDeniedMixed,
                  <String, String>{
                    'size': Formatters.formatBytes(
                      controller.lastFreedBytes.value,
                    ),
                  },
                )
              : AppStrings.tr(AppStrings.trashDeniedMessage),
          confirmLabel: AppStrings.tr(AppStrings.actionOk),
        );
      case TrashActionOutcome.restored:
      case TrashActionOutcome.failed:
      case TrashActionOutcome.serviceError:
      case null:
        // Failed / service errors render in the inline error strip.
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    void onBack() {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        controller.goToDeck();
      }
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          onBack();
        }
      },
      child: Obx(() {
        final bool isEmpty =
            !controller.isLoading.value && controller.entries.isEmpty;
        return AppScaffold(
          title: AppStrings.tr(AppStrings.screenTrash),
          leading: IconButton(
            icon: Icon(AppIcons.back, size: context.sizes.iconMd),
            tooltip: AppStrings.tr(AppStrings.actionBackToDeck),
            onPressed: onBack,
          ),
          // Phase 3A quick eye toggle: same global private-blur
          // setting as Review/Settings. Trash rows carry no
          // thumbnails, so this visibly changes Review, not here —
          // the toggle is still offered here for consistency.
          actions: <Widget>[
            IconButton(
              icon: Icon(
                controller.privateBlur.value ? AppIcons.eyeSlash : AppIcons.eye,
                size: context.sizes.iconMd,
              ),
              tooltip: AppStrings.tr(
                controller.privateBlur.value
                    ? AppStrings.blurShowPhotos
                    : AppStrings.blurHidePhotos,
              ),
              onPressed: controller.toggleBlur,
            ),
          ],
          bottomBar: isEmpty
              ? null
              : TrashBottomBar(
                  isBusy: controller.isBusy.value,
                  onRestoreAll: () => _restore(
                    context,
                    controller.entries.map((entry) => entry.assetId).toList(),
                  ),
                  onEmptyTrash: () => _emptyTrash(context),
                ),
          bottomNav: const AppBottomNav(currentIndex: 2),
          body: _ArrivalSnack(
            controller: controller,
            child: _AutoEmptyPrompt(
              controller: controller,
              child: _Body(
                controller: controller,
                onRestoreSingle: (String id) => _restore(context, <String>[id]),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.controller, required this.onRestoreSingle});

  final TrashController controller;
  final ValueChanged<String> onRestoreSingle;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value && controller.entries.isEmpty) {
        return const TrashLoadingSkeleton();
      }
      if (controller.errorKey.value.isNotEmpty && controller.entries.isEmpty) {
        return ErrorView(
          message: AppStrings.tr(controller.errorKey.value),
          onRetry: controller.init,
        );
      }
      if (controller.entries.isEmpty) {
        return EmptyView(
          icon: AppIcons.trash,
          title: AppStrings.tr(AppStrings.trashEmptyTitle),
          message: AppStrings.tr(AppStrings.trashEmptyMessage),
          ctaLabel: AppStrings.tr(AppStrings.actionBackToDeck),
          onCta: controller.goToDeck,
        );
      }
      return Column(
        children: <Widget>[
          if (controller.errorKey.value.isNotEmpty)
            ErrorBanner(
              message: AppStrings.tr(controller.errorKey.value),
              onDismiss: () => controller.errorKey.value = '',
            ),
          Expanded(
            child: ListView.builder(
              itemCount: controller.entries.length,
              itemBuilder: (BuildContext context, int index) {
                final entry = controller.entries[index];
                // Phase 3.4: keyed rows, so a restore keeps each
                // row's state with its entry instead of its slot.
                return TrashRow(
                  key: ValueKey<String>(entry.assetId),
                  entry: entry,
                  onRestore: () => onRestoreSingle(entry.assetId),
                );
              },
            ),
          ),
        ],
      );
    });
  }
}

/// Bottom-anchored actions: "Restore all" (secondary) and "Empty
/// trash" (destructive outline in the error colour — never a filled
/// primary, so the destructive action never looks like the primary
/// flow). The bar renders only while Trash is non-empty.
/// Shows the review delete's arrival snackbar once, on the first
/// frame after the Trash screen appears, then clears it so rebuilds
/// never repeat it.
class _ArrivalSnack extends StatefulWidget {
  const _ArrivalSnack({required this.controller, required this.child});

  final TrashController controller;
  final Widget child;

  @override
  State<_ArrivalSnack> createState() => _ArrivalSnackState();
}

class _ArrivalSnackState extends State<_ArrivalSnack> {
  Worker? _initWorker;
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller.arrivalSnackDate.value.isEmpty) {
      return;
    }
    // Phase 3.4: one feedback surface per arrival. The old code
    // fired on the first frame, before init had set the
    // auto-empty prompt flag — so a snackbar and the prompt
    // dialog could stack. Now the snackbar waits for init to
    // complete and yields to the dialog when it is pending
    // (the dialog is the actionable surface; the entries still
    // carry their recoverable-until dates).
    _initWorker = ever<bool>(
      widget.controller.initComplete,
      (_) => _maybeShow(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
  }

  @override
  void dispose() {
    _initWorker?.dispose();
    super.dispose();
  }

  void _maybeShow() {
    if (_shown || !widget.controller.initComplete.value) {
      return;
    }
    _shown = true;
    // Capture before consuming: the snackbar reads the date in
    // a post-frame callback. Consume exactly once in both
    // paths, so a later revisit never replays a stale arrival
    // snackbar.
    final String date = widget.controller.arrivalSnackDate.value;
    widget.controller.clearArrivalSnack();
    if (widget.controller.autoEmptyPromptPending.value) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      AppSnackbar.show(
        context,
        message: AppStrings.tr(
          AppStrings.snackMovedToTrashUntil,
          <String, String>{'date': date},
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Phase 3A auto-empty prompt (trust-rule resolution): shown once,
/// on the first frame, only when the setting is ON and expired
/// records exist. Confirming calls the controller's [emptyTrash]
/// directly — this dialog IS the in-app confirmation, and the
/// native sheet follows, so nothing here deletes silently.
/// Declining runs record-only cleanup of the expired records
/// (their system media is already gone); still-recoverable
/// records are never touched by either path.
class _AutoEmptyPrompt extends StatefulWidget {
  const _AutoEmptyPrompt({required this.controller, required this.child});

  final TrashController controller;
  final Widget child;

  @override
  State<_AutoEmptyPrompt> createState() => _AutoEmptyPromptState();
}

class _AutoEmptyPromptState extends State<_AutoEmptyPrompt> {
  bool _shown = false;
  Worker? _promptWorker;

  @override
  void initState() {
    super.initState();
    // The prompt flag is set asynchronously by the controller's
    // init (trash load, then settings load), so a one-shot check
    // here would miss it: listen for the flag turning true, and
    // also check the current value in case init already finished.
    _promptWorker = ever<bool>(widget.controller.autoEmptyPromptPending, (
      bool pending,
    ) {
      if (pending) {
        _maybeShow();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
  }

  @override
  void dispose() {
    _promptWorker?.dispose();
    super.dispose();
  }

  void _maybeShow() {
    if (_shown || !widget.controller.autoEmptyPromptPending.value) {
      return;
    }
    _shown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      final bool confirmed = await AppDialog.showConfirmation(
        context,
        title: AppStrings.tr(AppStrings.trashAutoEmptyPromptTitle),
        message: AppStrings.tr(AppStrings.trashAutoEmptyPromptMessage),
        confirmLabel: AppStrings.tr(AppStrings.trashEmpty),
        cancelLabel: AppStrings.tr(AppStrings.actionCancel),
        isDestructive: true,
      );
      if (!mounted) {
        return;
      }
      if (confirmed) {
        await widget.controller.emptyTrash();
      } else {
        await widget.controller.cleanupExpiredRecords();
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
