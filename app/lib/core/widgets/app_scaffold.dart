import 'package:flutter/material.dart';

import '../theme/theme_ext.dart';

/// Shared screen frame (design.md §10). Background comes from the
/// palette; the app bar is flat with no elevation. Views supply an
/// already-resolved title string (via [AppStrings] keys), a [titleWidget]
/// (e.g. the brand wordmark), or none.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.title,
    this.titleWidget,
    this.leading,
    this.actions,
    this.bottomBar,
    this.bottomNav,
    this.floatingActionButton,
  });

  final Widget body;
  final String? title;

  /// Replaces the text title when supplied; takes precedence over [title].
  final Widget? titleWidget;

  /// Overrides the AppBar's automatic back button. Review, trash and
  /// history pass their own back control so back always resets the
  /// stack to the deck instead of popping into a stale controller.
  final Widget? leading;
  final List<Widget>? actions;
  final Widget? bottomBar;
  final Widget? bottomNav;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final String? title = this.title;
    final Widget? titleWidget = this.titleWidget;
    final Widget? nav = (bottomBar != null || bottomNav != null)
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (bottomBar != null)
                MediaQuery.removePadding(
                  context: context,
                  removeBottom: bottomNav != null,
                  child: bottomBar!,
                ),
              ?bottomNav,
            ],
          )
        : null;
    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: title == null && titleWidget == null
          ? null
          : AppBar(
              title: titleWidget ?? Text(title!),
              leading: leading,
              actions: actions,
            ),
      body: body,
      bottomNavigationBar: nav,
      floatingActionButton: floatingActionButton,
    );
  }
}
