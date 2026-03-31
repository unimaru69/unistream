import '../l10n/app_localizations.dart';
import '../services/xtream_api.dart';

/// Maps an [ApiErrorKey] to a localized user-facing error message.
String localizeApiError(ApiErrorKey key, AppLocalizations l10n) {
  switch (key) {
    case ApiErrorKey.network:
      return l10n.errConnexionImpossible;
    case ApiErrorKey.timeout:
      return l10n.errServeurNeRepond;
    case ApiErrorKey.client:
      return l10n.errCommunication;
    case ApiErrorKey.format:
      return l10n.errReponseInvalide;
    case ApiErrorKey.auth:
      return l10n.errIdentifiants;
    case ApiErrorKey.generic:
      return l10n.errGenerique;
  }
}
