import 'package:flutter/material.dart';

import '../theme/theme_ext.dart';

/// Shared screen frame (design.md §10). Background comes from the
/// palette; the app bar is flat with no elevation. Views supply an
/// already-resolved title string (via [AppStrings] keys) or none.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.title,
    this.leading,
    this.actions,
    this.bottomBar,
    this.floatingActionButton,
  });

  final Widget body;
  final String? title;

  /// Overrides the AppBar's automatic back button. Review, trash and
  /// history pass their own back control so back always resets the
  /// stack to the deck instead of popping into a stale controller.
  final Widget? leading;
  final List<Widget>? actions;
  final Widget? bottomBar;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final String? title = this.title;
    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: title == null
          ? null
          : AppBar(title: Text(title), leading: leading, actions: actions),
      body: body,
      bottomNavigationBar: bottomBar,
      floatingActionButton: floatingActionButton,
    );
  }
}
