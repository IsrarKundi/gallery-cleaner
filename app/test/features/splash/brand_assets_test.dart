import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Validates the generated brand assets (design.md §13): both Lottie
/// files parse, carry five letter layers plus a final dot layer, and run
/// ~1.67s; both logo SVGs carry the same letter paths and a blue dot.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('brand assets', () {
    for (final String file in <String>[
      'assets/animations/klara_logo_lottie.json',
      'assets/animations/klara_logo_lottie_white.json',
    ]) {
      test('$file parses with letter layers, final dot, ~1.67s', () async {
        final String raw = await rootBundle.loadString(file);
        final Map<String, dynamic> doc =
            jsonDecode(raw) as Map<String, dynamic>;
        final double duration =
            (doc['op'] as num).toDouble() / (doc['fr'] as num).toDouble();
        expect(duration, closeTo(1.67, 0.01));
        final List<dynamic> layers = doc['layers'] as List<dynamic>;
        expect(layers.length, 6);
        final List<String> names = layers
            .map(
              (dynamic layer) =>
                  (layer as Map<String, dynamic>)['nm'] as String,
            )
            .toList();
        expect(names.last, 'dot');
        expect(
          names.sublist(0, 5).every((String n) => n.startsWith('letter_')),
          isTrue,
        );
        // Every letter layer animates opacity and position (rise + fade).
        for (final dynamic layer in layers.sublist(0, 5)) {
          final Map<String, dynamic> ks =
              (layer as Map<String, dynamic>)['ks'] as Map<String, dynamic>;
          expect((ks['o'] as Map<String, dynamic>)['a'], 1);
          expect((ks['p'] as Map<String, dynamic>)['a'], 1);
        }
      });
    }

    test('logo SVGs share letter paths and carry a blue dot', () async {
      final String ink = await rootBundle.loadString(
        'assets/icons/klara_logo.svg',
      );
      final String white = await rootBundle.loadString(
        'assets/icons/klara_logo_white.svg',
      );
      expect(ink, contains('#202124'));
      expect(white, contains('#FFFFFF'));
      for (final String svg in <String>[ink, white]) {
        expect(svg, contains('#4285F4'));
        expect(svg, contains('<path d="'));
        expect(svg, contains('<circle'));
      }
      // Same path data in both files: only the letter fill differs.
      final String inkPath = ink.split('<path d="')[1].split('"')[0];
      final String whitePath = white.split('<path d="')[1].split('"')[0];
      expect(whitePath, inkPath);
    });
  });
}
