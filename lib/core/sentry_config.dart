/// Sentry DSN — replace with your actual DSN from https://sentry.io
/// Set to empty string to disable Sentry (dev mode).
const String sentryDsn = 'https://6bdfb99f88918c89b2cc54360f42932c@o4511139441016832.ingest.de.sentry.io/4511139448488016';

/// Whether Sentry is configured and should be active.
bool get isSentryEnabled => sentryDsn.isNotEmpty;
