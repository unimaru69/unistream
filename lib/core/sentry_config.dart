/// Sentry DSN — replace with your actual DSN from https://sentry.io
/// Set to empty string to disable Sentry (dev mode).
const String sentryDsn = '';

/// Whether Sentry is configured and should be active.
bool get isSentryEnabled => sentryDsn.isNotEmpty;
