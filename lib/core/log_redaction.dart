import 'package:sentry_flutter/sentry_flutter.dart';

import '../models/app_config.dart';

/// Redaction of Xtream credentials on anything leaving the device as
/// diagnostics.
///
/// Every call the app makes to an Xtream panel carries the subscription
/// login and password — in the query string for the API
/// (`player_api.php?username=X&password=Y`) and in the path for streams
/// (`{server}/movie/{user}/{pass}/{id}.mkv`). `AppLogger.error` forwards
/// its exception to Sentry, and an exception raised around an HTTP call is
/// one interpolated URL away from carrying those credentials to a third
/// party. Rather than audit every present and future log line, scrub at
/// the exit.
///
/// `sendDefaultPii = false` does not cover this: it governs what the SDK
/// itself attaches (IP, user), not what our own strings contain.

/// Query parameters whose value is a credential.
final _credentialQueryParam = RegExp(
  r'''([?&](?:username|password|pass|user)=)([^&\s"']+)''',
  caseSensitive: false,
);

/// Stream paths: `/live/<user>/<pass>/…`, and the movie / series /
/// timeshift variants, which all put the credentials in the same two
/// segments.
final _credentialPathSegments = RegExp(
  r'(/(?:live|movie|series|timeshift)/)([^/\s]+)/([^/\s]+)/',
  caseSensitive: false,
);

const _mask = '***';

/// Minimum length before a credential is replaced by literal match.
///
/// A one- or two-character password would otherwise turn every incidental
/// occurrence of those characters into `***` and shred the diagnostics we
/// went to Sentry for in the first place. Short credentials are still
/// covered by the two patterns above, which is where they realistically
/// appear.
const _minLiteralLength = 4;

/// Strip credentials out of an arbitrary diagnostic string.
String redactCredentials(String input) {
  if (input.isEmpty) return input;
  var out = input
      .replaceAllMapped(_credentialQueryParam, (m) => '${m[1]}$_mask')
      .replaceAllMapped(_credentialPathSegments, (m) => '${m[1]}$_mask/$_mask/');

  // Belt and braces: the live credentials, matched literally, for shapes
  // the patterns above don't anticipate (a bare password logged on its
  // own, a provider using a different URL layout).
  for (final secret in [AppConfig.password, AppConfig.username]) {
    if (secret.length >= _minLiteralLength) {
      out = out.replaceAll(secret, _mask);
    }
  }
  return out;
}

Object? _redactValue(Object? value) {
  if (value is String) return redactCredentials(value);
  if (value is Map) {
    return value.map((k, v) => MapEntry(k, _redactValue(v)));
  }
  if (value is List) return value.map(_redactValue).toList();
  return value;
}

/// `beforeBreadcrumb` hook — breadcrumbs carry both a message and a free
/// `data` map, and `AppLogger.breadcrumb` call sites pass whatever the
/// caller had at hand.
Breadcrumb? redactBreadcrumb(Breadcrumb? crumb) {
  if (crumb == null) return null;
  final message = crumb.message;
  if (message != null) crumb.message = redactCredentials(message);
  final data = crumb.data;
  if (data != null) {
    crumb.data = data.map((k, v) => MapEntry(k, _redactValue(v)));
  }
  return crumb;
}

/// `beforeSend` hook — covers the message, every exception value, the
/// request URL and any breadcrumb already attached to the event.
SentryEvent? redactSentryEvent(SentryEvent event) {
  final message = event.message;
  if (message != null) {
    message.formatted = redactCredentials(message.formatted);
    final template = message.template;
    if (template != null) message.template = redactCredentials(template);
  }

  for (final exception in event.exceptions ?? const <SentryException>[]) {
    final value = exception.value;
    if (value != null) exception.value = redactCredentials(value);
  }

  final request = event.request;
  final requestUrl = request?.url;
  if (request != null && requestUrl != null) {
    request.url = redactCredentials(requestUrl);
  }

  for (final crumb in event.breadcrumbs ?? const <Breadcrumb>[]) {
    redactBreadcrumb(crumb);
  }

  return event;
}
