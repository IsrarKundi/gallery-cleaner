// The review ask sheet (fix plan Stage 5, ADR-020).
//
// Cleanup's two-step shape (teardown notes/retention.md §4.3)
// in the owner's decided design (30 Oct 2026): OUR sheet first —
// the heart-paws kitten, five soft gold stars, "You just freed
// up {amount}", "Let's Go!" / "Maybe Later". "Let's Go!" hands
// over to the store prompt; the negative path ("Not happy?
// Tell us what's wrong") swaps THIS sheet to a feedback form —
// sheets never stack (design.md §6) — and submitting hands the
// text to the system share sheet via the service, so the user
// picks the destination; nothing is sent silently (decision
// 11).
//
// Shared by the three ask places (finish screen, deck session
// end, home), so it lives in the shared kit; it drives the
// ask through the [ReviewAskService] interface only — the
// hosting controller supplies the service (null = never ask).

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../services/review_ask/review_ask.dart';
import '../../services/review_ask/review_ask_service.dart';
import '../strings/app_strings.dart';
import '../theme/theme_ext.dart';
import '../utils/formatters.dart';
import 'app_snackbar.dart';
import 'primary_button.dart';
import 'secondary_button.dart';

/// What the sheet produced.
enum _Outcome { dismissed, review, feedback }

class _Result {
  const _Result(this.outcome, [this.text]);

  final _Outcome outcome;
  final String? text;
}

class ReviewAskSheet {
  ReviewAskSheet._();

  static const String _kittenAsset = 'assets/images/img_rate_kitten.png';
  static const String _starsAsset = 'assets/images/img_rate_stars.svg';

  /// Presents [place]'s ask when it is due, then routes the
  /// outcome through [service]: review → store prompt, feedback
  /// → share hand-off, dismissal → re-arm at double the count.
  /// Records the presentation before showing, so a crash
  /// mid-sheet still counts the place as shown. Returns true
  /// when a sheet was presented.
  static Future<bool> maybeShow(
    BuildContext context, {
    required ReviewAskService service,
    required ReviewAskPlace place,
    required int amountBytes,
  }) async {
    if (!await service.isDue(place)) {
      return false;
    }
    if (!context.mounted) {
      return false;
    }
    await service.markShown(place);
    if (!context.mounted) {
      return false;
    }
    final _Result result =
        await showModalBottomSheet<_Result>(
          context: context,
          backgroundColor: context.palette.surface,
          isScrollControlled: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(context.sizes.radiusSheet),
            ),
          ),
          builder: (BuildContext sheetContext) {
            return _SheetContent(amountBytes: amountBytes);
          },
        ) ??
        const _Result(_Outcome.dismissed);
    switch (result.outcome) {
      case _Outcome.review:
        await service.answerWithReview();
      case _Outcome.feedback:
        await service.answerWithFeedback(result.text ?? '');
        if (context.mounted) {
          AppSnackbar.show(
            context,
            message: AppStrings.tr(AppStrings.feedbackThanks),
          );
        }
      case _Outcome.dismissed:
        await service.markDismissed(place);
    }
    return true;
  }
}

/// The sheet's two modes in one widget: the ask, then (on the
/// unhappy path) the feedback form in the same sheet.
class _SheetContent extends StatefulWidget {
  const _SheetContent({required this.amountBytes});

  final int amountBytes;

  @override
  State<_SheetContent> createState() => _SheetContentState();
}

class _SheetContentState extends State<_SheetContent> {
  bool _feedbackMode = false;
  final TextEditingController _feedbackText = TextEditingController();

  @override
  void dispose() {
    _feedbackText.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: context.sizes.screenPadding,
          right: context.sizes.screenPadding,
          top: context.sizes.lg,
          bottom: context.sizes.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: _feedbackMode ? _buildFeedback(context) : _buildAsk(context),
      ),
    );
  }

  Widget _buildAsk(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(
          child: Image.asset(
            ReviewAskSheet._kittenAsset,
            width: context.sizes.celebrationArt,
            fit: BoxFit.contain,
          ),
        ),
        SizedBox(height: context.sizes.sm),
        Center(
          child: SvgPicture.asset(
            ReviewAskSheet._starsAsset,
            height: context.sizes.iconLg,
          ),
        ),
        SizedBox(height: context.sizes.md),
        Text(
          AppStrings.tr(AppStrings.reviewAskTitle, <String, String>{
            'amount': Formatters.formatBytes(widget.amountBytes),
          }),
          style: context.textStyles.headlineSmall,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: context.sizes.sm),
        Text(
          AppStrings.tr(AppStrings.reviewAskBody),
          style: context.textStyles.bodyMedium.copyWith(
            color: context.palette.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: context.sizes.lg),
        PrimaryButton(
          label: AppStrings.tr(AppStrings.reviewAskGo),
          onPressed: () =>
              Navigator.of(context).pop(const _Result(_Outcome.review)),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(const _Result(_Outcome.dismissed)),
          child: Text(
            AppStrings.tr(AppStrings.reviewAskLater),
            style: context.textStyles.labelLarge.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
        ),
        TextButton(
          onPressed: () => setState(() => _feedbackMode = true),
          child: Text(
            AppStrings.tr(AppStrings.reviewAskNotHappy),
            style: context.textStyles.labelMedium.copyWith(
              color: context.palette.textTertiary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeedback(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          AppStrings.tr(AppStrings.feedbackTitle),
          style: context.textStyles.titleLarge,
        ),
        SizedBox(height: context.sizes.md),
        TextField(
          controller: _feedbackText,
          maxLines: 5,
          minLines: 3,
          autofocus: true,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(
            hintText: AppStrings.tr(AppStrings.feedbackHint),
          ),
          onChanged: (_) => setState(() {}),
        ),
        SizedBox(height: context.sizes.lg),
        PrimaryButton(
          label: AppStrings.tr(AppStrings.feedbackSubmit),
          onPressed: _feedbackText.text.trim().isEmpty
              ? null
              : () => Navigator.of(context)
                    .pop(_Result(_Outcome.feedback, _feedbackText.text.trim())),
        ),
        SizedBox(height: context.sizes.sm),
        SecondaryButton(
          label: AppStrings.tr(AppStrings.actionCancel),
          onPressed: () =>
              Navigator.of(context).pop(const _Result(_Outcome.dismissed)),
        ),
      ],
    );
  }
}
