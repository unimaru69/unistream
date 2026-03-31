import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/screens/player/widgets/next_episode_overlay.dart';

import '../../helpers/test_wrapper.dart';

void main() {
  group('NextEpisodeOverlay', () {
    Widget buildOverlay({
      Map<String, dynamic>? episode,
      int countdownSec = 10,
      VoidCallback? onPlayNow,
      VoidCallback? onCancel,
    }) {
      return testApp(
        Stack(
          children: [
            NextEpisodeOverlay(
              nextEpisode: episode ?? {'title': 'S01E02 - Le retour'},
              countdownSec: countdownSec,
              onPlayNow: onPlayNow ?? () {},
              onCancel: onCancel ?? () {},
            ),
          ],
        ),
      );
    }

    testWidgets('shows episode title', (tester) async {
      await tester.pumpWidget(buildOverlay());
      await tester.pumpAndSettle();

      expect(find.text('S01E02 - Le retour'), findsOneWidget);
    });

    testWidgets('shows countdown in play button', (tester) async {
      await tester.pumpWidget(buildOverlay(countdownSec: 7));
      await tester.pumpAndSettle();

      expect(find.text('Lire maintenant (7)'), findsOneWidget);
    });

    testWidgets('cancel button triggers callback', (tester) async {
      var cancelled = false;
      await tester.pumpWidget(buildOverlay(
        onCancel: () => cancelled = true,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Annuler'));
      expect(cancelled, isTrue);
    });
  });
}
