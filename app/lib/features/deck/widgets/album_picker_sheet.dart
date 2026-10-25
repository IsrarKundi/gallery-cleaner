import 'package:flutter/material.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../services/media/media_asset.dart';

/// Modal bottom sheet for choosing an album to add photos to.
class AlbumPickerSheet extends StatelessWidget {
  const AlbumPickerSheet({
    super.key,
    required this.albums,
    required this.onAlbumSelected,
  });

  final List<MediaAlbum> albums;
  final ValueChanged<MediaAlbum> onAlbumSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
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
              AppStrings.tr(AppStrings.actionAddToAlbum),
              style: context.textStyles.titleLarge,
            ),
            SizedBox(height: context.sizes.md),
            if (albums.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: context.sizes.lg),
                child: Center(
                  child: Text(
                    AppStrings.tr(AppStrings.decksEmpty),
                    style: context.textStyles.bodyMedium,
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.4,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: albums.length,
                  separatorBuilder: (BuildContext context, int index) =>
                      Divider(color: context.palette.border, height: 1),
                  itemBuilder: (BuildContext context, int index) {
                    final MediaAlbum album = albums[index];
                    return ListTile(
                      leading: Icon(
                        AppIcons.photos,
                        size: context.sizes.iconMd,
                        color: context.palette.textSecondary,
                      ),
                      title: Text(
                        album.name,
                        style: context.textStyles.bodyMedium,
                      ),
                      trailing: Text(
                        album.count.toString(),
                        style: context.textStyles.bodySmall.copyWith(
                          color: context.palette.textSecondary,
                        ),
                      ),
                      onTap: () => onAlbumSelected(album),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
