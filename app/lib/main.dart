import 'package:flutter/material.dart';

// Phase 1 bootstrap placeholder only: a bare scaffold with no buttons and
// no features. This file will be replaced by the GetX routing setup
// (core/routes + initial binding) in a later increment.
void main() {
  runApp(const KlaraApp());
}

class KlaraApp extends StatelessWidget {
  const KlaraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Klara',
      theme: ThemeData(fontFamily: 'Inter'),
      home: const Scaffold(body: SizedBox.shrink()),
    );
  }
}
