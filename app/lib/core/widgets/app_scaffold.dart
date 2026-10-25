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
    this.actions,
    this.bottomBar,
    this.floatingActionButton,
  });

  final Widget body;
  final String? title;
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
          : AppBar(title: Text(title), actions: actions),
      body: body,
      bottomNavigationBar: bottomBar,
      floatingActionButton: floatingActionButton,
    );
  }
}
