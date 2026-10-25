import 'package:flutter/material.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/utils/formatters.dart';
import '../controller/deck_controller.dart';
import '../model/deck_filter.dart';

/// Filter bottom sheet (requirements §7, Phase 1 only): All, a month
/// list and an album list, plus Clear. No smart-deck entries — those
/// are Phase 2. Picking a filter starts a fresh queue under a new
/// session key; the sheet closes on selection.
class FilterSheet extends StatelessWidget {
  const FilterSheet({super.key, required this.controller});

  final DeckController controller;

  void _select(BuildContext context, DeckFilter next) {
    controller.setFilter(next);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final DeckFilter current = controller.filter.value;
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(context.sizes.screenPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: context.sizes.huge,
                  height: context.sizes.xs,
                  decoration: BoxDecoration(
                    color: context.palette.border,
                    borderRadius: BorderRadius.circular(context.sizes.pill),
                  ),
                ),
              ),
              SizedBox(height: context.sizes.lg),
              Text(
                AppStrings.tr(AppStrings.filterTitle),
                style: context.textStyles.titleLarge,
              ),
              SizedBox(height: context.sizes.sm),
              ListTile(
                leading: Icon(AppIcons.photos, size: context.sizes.iconMd),
                title: Text(AppStrings.tr(AppStrings.filterAll)),
                trailing: current.isAll
                    ? Icon(AppIcons.check, size: context.sizes.iconMd)
                    : null,
                onTap: () => _select(context, const DeckFilter.all()),
              ),
              for (final String monthKey in controller.months)
                ListTile(
                  leading: Icon(AppIcons.photos, size: context.sizes.iconMd),
                  title: Text(monthLabel(monthKey)),
                  trailing:
                      current.kind == DeckFilterKind.month &&
                          current.monthKey == monthKey
                      ? Icon(AppIcons.check, size: context.sizes.iconMd)
                      : null,
                  onTap: () => _select(context, DeckFilter.month(monthKey)),
                ),
              for (final album in controller.albums)
                ListTile(
                  leading: Icon(AppIcons.photos, size: context.sizes.iconMd),
                  title: Text(album.name),
                  subtitle: Text(Formatters.formatCount(album.count)),
                  trailing:
                      current.kind == DeckFilterKind.album &&
                          current.albumId == album.id
                      ? Icon(AppIcons.check, size: context.sizes.iconMd)
                      : null,
                  onTap: () => _select(context, DeckFilter.album(album.id)),
                ),
              SizedBox(height: context.sizes.sm),
              TextButton(
                onPressed: () => _select(context, const DeckFilter.all()),
                child: Text(AppStrings.tr(AppStrings.clearFilters)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
