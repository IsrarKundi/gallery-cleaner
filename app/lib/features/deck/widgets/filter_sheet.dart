import 'package:flutter/material.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../core/utils/formatters.dart';
import '../controller/deck_controller.dart';
import '../model/deck_filter.dart';
import '../../../services/media/media_asset.dart';

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
    // Phase 3.4: the old SingleChildScrollView + Column built
    // every month and album row eagerly. The rows now build
    // lazily in one list (All, then months, then albums, then
    // Clear), inside a fixed 70%-of-screen sheet so the list has
    // a bounded height to scroll in. Behaviour change to note:
    // the sheet no longer sizes to its content.
    final List<String> months = controller.months.toList();
    final List<MediaAlbum> albums = controller.albums.toList();
    final int itemCount = 1 + months.length + albums.length + 1;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Padding(
          padding: EdgeInsets.all(context.sizes.screenPadding),
          child: Column(
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
              Expanded(
                child: ListView.builder(
                  itemCount: itemCount,
                  itemBuilder: (BuildContext context, int index) {
                    if (index == 0) {
                      return ListTile(
                        leading: Icon(
                          AppIcons.photos,
                          size: context.sizes.iconMd,
                        ),
                        title: Text(AppStrings.tr(AppStrings.filterAll)),
                        trailing: current.isAll
                            ? Icon(AppIcons.check, size: context.sizes.iconMd)
                            : null,
                        onTap: () => _select(context, const DeckFilter.all()),
                      );
                    }
                    final int monthIndex = index - 1;
                    if (monthIndex < months.length) {
                      final String monthKey = months[monthIndex];
                      return ListTile(
                        leading: Icon(
                          AppIcons.photos,
                          size: context.sizes.iconMd,
                        ),
                        title: Text(monthLabel(monthKey)),
                        trailing:
                            current.kind == DeckFilterKind.month &&
                                current.monthKey == monthKey
                            ? Icon(AppIcons.check, size: context.sizes.iconMd)
                            : null,
                        onTap: () =>
                            _select(context, DeckFilter.month(monthKey)),
                      );
                    }
                    final int albumIndex = monthIndex - months.length;
                    if (albumIndex < albums.length) {
                      final MediaAlbum album = albums[albumIndex];
                      return ListTile(
                        leading: Icon(
                          AppIcons.photos,
                          size: context.sizes.iconMd,
                        ),
                        title: Text(album.name),
                        subtitle: Text(Formatters.formatCount(album.count)),
                        trailing:
                            current.kind == DeckFilterKind.album &&
                                current.albumId == album.id
                            ? Icon(AppIcons.check, size: context.sizes.iconMd)
                            : null,
                        onTap: () =>
                            _select(context, DeckFilter.album(album.id)),
                      );
                    }
                    return TextButton(
                      onPressed: () => _select(context, const DeckFilter.all()),
                      child: Text(AppStrings.tr(AppStrings.clearFilters)),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
