import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/l10n/app_localizations.dart';
import 'package:unistream/widgets/pin_dialog.dart';

void main() {
  Widget buildTestApp({
    String title = 'Test PIN',
    String? errorMessage,
    int pinLength = 4,
    ValueChanged<String>? onPinEntered,
    VoidCallback? onCancel,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('fr'),
      home: Scaffold(
        body: PinDialog(
          title: title,
          errorMessage: errorMessage,
          pinLength: pinLength,
          onPinEntered: onPinEntered ?? (_) {},
          onCancel: onCancel ?? () {},
        ),
      ),
    );
  }

  group('PinDialog', () {
    testWidgets('renders title', (tester) async {
      await tester.pumpWidget(buildTestApp(title: 'Enter PIN'));
      expect(find.text('Enter PIN'), findsOneWidget);
    });

    testWidgets('renders numeric keypad with all digits', (tester) async {
      await tester.pumpWidget(buildTestApp());
      for (var i = 0; i <= 9; i++) {
        expect(find.text('$i'), findsOneWidget);
      }
    });

    testWidgets('renders correct number of dot indicators', (tester) async {
      await tester.pumpWidget(buildTestApp(pinLength: 4));
      // 4 circle containers for dots
      final dotFinder = find.byWidgetPredicate((w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).shape == BoxShape.circle);
      expect(dotFinder, findsNWidgets(4));
    });

    testWidgets('tapping digits enters PIN', (tester) async {
      String? enteredPin;
      await tester.pumpWidget(buildTestApp(
        pinLength: 4,
        onPinEntered: (pin) => enteredPin = pin,
      ));

      // Tap 1, 2, 3, 4
      await tester.tap(find.text('1'));
      await tester.pump();
      await tester.tap(find.text('2'));
      await tester.pump();
      await tester.tap(find.text('3'));
      await tester.pump();
      await tester.tap(find.text('4'));
      await tester.pump();

      expect(enteredPin, equals('1234'));
    });

    testWidgets('backspace removes last digit', (tester) async {
      String? enteredPin;
      await tester.pumpWidget(buildTestApp(
        pinLength: 4,
        onPinEntered: (pin) => enteredPin = pin,
      ));

      await tester.tap(find.text('1'));
      await tester.pump();
      await tester.tap(find.text('2'));
      await tester.pump();

      // Tap backspace
      await tester.tap(find.byIcon(Icons.backspace_outlined));
      await tester.pump();

      // Now enter 3, 4, 5 to complete
      await tester.tap(find.text('3'));
      await tester.pump();
      await tester.tap(find.text('4'));
      await tester.pump();
      await tester.tap(find.text('5'));
      await tester.pump();

      // PIN should be 1 + 3 + 4 + 5 = "1345"
      expect(enteredPin, equals('1345'));
    });

    testWidgets('C button clears all digits', (tester) async {
      String? enteredPin;
      await tester.pumpWidget(buildTestApp(
        pinLength: 4,
        onPinEntered: (pin) => enteredPin = pin,
      ));

      await tester.tap(find.text('1'));
      await tester.pump();
      await tester.tap(find.text('2'));
      await tester.pump();

      // Clear
      await tester.tap(find.text('C'));
      await tester.pump();

      // Enter full PIN
      await tester.tap(find.text('5'));
      await tester.pump();
      await tester.tap(find.text('6'));
      await tester.pump();
      await tester.tap(find.text('7'));
      await tester.pump();
      await tester.tap(find.text('8'));
      await tester.pump();

      expect(enteredPin, equals('5678'));
    });

    testWidgets('shows error message when provided', (tester) async {
      await tester.pumpWidget(
          buildTestApp(errorMessage: 'PIN incorrect'));
      expect(find.text('PIN incorrect'), findsOneWidget);
    });

    testWidgets('cancel button calls onCancel', (tester) async {
      bool cancelled = false;
      await tester.pumpWidget(buildTestApp(
        onCancel: () => cancelled = true,
      ));

      await tester.tap(find.text('Annuler'));
      await tester.pump();

      expect(cancelled, isTrue);
    });

    testWidgets('supports 6-digit PIN', (tester) async {
      String? enteredPin;
      await tester.pumpWidget(buildTestApp(
        pinLength: 6,
        onPinEntered: (pin) => enteredPin = pin,
      ));

      for (final d in ['1', '2', '3', '4', '5', '6']) {
        await tester.tap(find.text(d));
        await tester.pump();
      }

      expect(enteredPin, equals('123456'));
    });
  });
}
