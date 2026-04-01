import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/services/xtream_api.dart';
import 'package:unistream/utils/api_error_localizer.dart';
import 'package:unistream/l10n/app_localizations.dart';

void main() {
  group('localizeApiError', () {
    late AppLocalizations l10n;

    setUp(() async {
      // Load French localizations for testing
      l10n = await AppLocalizations.delegate.load(const Locale('fr'));
    });

    test('network key returns errConnexionImpossible', () {
      final result = localizeApiError(ApiErrorKey.network, l10n);
      expect(result, l10n.errConnexionImpossible);
      expect(result, isNotEmpty);
    });

    test('timeout key returns errServeurNeRepond', () {
      final result = localizeApiError(ApiErrorKey.timeout, l10n);
      expect(result, l10n.errServeurNeRepond);
      expect(result, isNotEmpty);
    });

    test('client key returns errCommunication', () {
      final result = localizeApiError(ApiErrorKey.client, l10n);
      expect(result, l10n.errCommunication);
      expect(result, isNotEmpty);
    });

    test('format key returns errReponseInvalide', () {
      final result = localizeApiError(ApiErrorKey.format, l10n);
      expect(result, l10n.errReponseInvalide);
      expect(result, isNotEmpty);
    });

    test('auth key returns errIdentifiants', () {
      final result = localizeApiError(ApiErrorKey.auth, l10n);
      expect(result, l10n.errIdentifiants);
      expect(result, isNotEmpty);
    });

    test('generic key returns errGenerique', () {
      final result = localizeApiError(ApiErrorKey.generic, l10n);
      expect(result, l10n.errGenerique);
      expect(result, isNotEmpty);
    });

    test('all error keys produce different messages', () {
      final messages = ApiErrorKey.values
          .map((key) => localizeApiError(key, l10n))
          .toSet();
      expect(messages.length, ApiErrorKey.values.length);
    });
  });
}
