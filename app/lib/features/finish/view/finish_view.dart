// Finish screen (fix plan Stage 5, ADR-020 decisions 1–2).
//
// Shown after a delete batch completes: the Fluent party
// popper (the owner's decided asset), "Congratulations!", and
// two honest rows — how many photos were deleted, and the
// space with its TRUE state (freed for a Review batch; "In
// Trash — freed on [date]" for a system-trash batch). No
// saved-time row: there is no honest way to measure it.
//
// Presenting the delete-place review ask lives here too: once
// the screen is up, the ask sheet may follow (the TrashView
// arrival-snack pattern — a stateful prompt wrapper owns the
// post-frame presentation; the view itself stays layout-only).

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/review_ask_sheet.dart';
import '../../../services/review_ask/review_ask.dart';
import '../../../services/review_ask/review_ask_service.dart';
import '../controller/finish_controller.dart';
import '../model/finish_summary.dart';

class FinishView extends GetView<FinishController> {
  const FinishView({super.key});

  static const String _popperAsset = 'assets/images/img_party_popper.svg';

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          controller.done();
        }
      },
      child: AppScaffold(
        body: Obx(() {
          final FinishSummary? summary = controller.summary;
          if (!controller.isReady.value || summary == null) {
            return const SizedBox.shrink();
          }
          return _AskPrompt(
            service: controller.reviewAsk,
            amountBytes: summary.sizeBytes,
            child: _Content(summary: summary),
          );
        }),
        bottomBar: Obx(() {
          if (!controller.isReady.value) {
            return const SizedBox.shrink();
          }
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.all(context.sizes.screenPadding),
              child: PrimaryButton(
                label: AppStrings.tr(AppStrings.finishDone),
                onPressed: controller.done,
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.summary});

  final FinishSummary summary;

  @override
  Widget build(BuildContext context) {
    final bool freed = summary.spaceState == FinishSpaceState.freed;
    final DateTime? until = summary.recoverableUntil;
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: context.sizes.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(height: context.sizes.giant),
          Center(
            child: SvgPicture.asset(
              FinishView._popperAsset,
              width: context.sizes.celebrationArt,
            ),
          ),
          SizedBox(height: context.sizes.lg),
          Text(
            AppStrings.tr(AppStrings.finishTitle),
            style: context.textStyles.headlineSmall,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: context.sizes.sm),
          Text(
            AppStrings.tr(AppStrings.finishSubtitle),
            style: context.textStyles.bodyMedium.copyWith(
              color: context.palette.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: context.sizes.xl),
          _ResultRow(
            icon: AppIcons.check,
            iconColor: context.palette.success,
            value: AppStrings.tr(AppStrings.finishPhotosCount, <String, String>{
              'count': Formatters.formatCount(summary.deletedCount),
            }),
            caption: AppStrings.tr(AppStrings.finishDeletedCaption),
          ),
          SizedBox(height: context.sizes.md),
          _ResultRow(
            icon: AppIcons.large,
            iconColor: context.palette.primary,
            value: Formatters.formatBytes(summary.sizeBytes),
            caption: freed
                ? AppStrings.tr(AppStrings.finishFreedCaption)
                : until == null
                ? AppStrings.tr(AppStrings.finishInTrashNoDateCaption)
                : AppStrings.tr(
                    AppStrings.finishInTrashCaption,
                    <String, String>{'date': Formatters.formatDate(until)},
                  ),
          ),
        ],
      ),
    );
  }
}

/// One result card: a white circle with the row's icon, then
/// the value over its caption (the decided mockup's shape, in
/// app tokens).
class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.caption,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.palette.primaryContainer,
        borderRadius: BorderRadius.circular(context.sizes.radiusLg),
      ),
      padding: EdgeInsets.all(context.sizes.md),
      child: Row(
        children: <Widget>[
          Container(
            width: context.sizes.buttonPrimary,
            height: context.sizes.buttonPrimary,
            decoration: BoxDecoration(
              color: context.palette.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: context.sizes.iconMd),
          ),
          SizedBox(width: context.sizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(value, style: context.textStyles.titleLarge),
                Text(
                  caption,
                  style: context.textStyles.bodyMedium.copyWith(
                    color: context.palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Presents the delete-place review ask once, after the finish
/// screen's first frame (never during build).
class _AskPrompt extends StatefulWidget {
  const _AskPrompt({
    required this.service,
    required this.amountBytes,
    required this.child,
  });

  final ReviewAskService? service;
  final int amountBytes;
  final Widget child;

  @override
  State<_AskPrompt> createState() => _AskPromptState();
}

class _AskPromptState extends State<_AskPrompt> {
  bool _asked = false;

  @override
  void initState() {
    super.initState();
    final ReviewAskService? service = widget.service;
    if (service == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _asked) {
        return;
      }
      _asked = true;
      ReviewAskSheet.maybeShow(
        context,
        service: service,
        place: ReviewAskPlace.delete,
        amountBytes: widget.amountBytes,
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
