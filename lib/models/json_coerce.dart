/// JSON coercion helpers for Xtream Codes responses.
///
/// Xtream panels are inconsistent across servers: some return id fields like
/// `category_id` as strings (`"1"`), others as numbers (`1`). A strict
/// `as String` cast throws a `TypeError` on the numeric form, which surfaced
/// as the generic "Une erreur est survenue" error after switching servers.
/// These helpers normalise any scalar JSON value to a String.
library;

/// Coerce a JSON value to a non-null String. Null becomes the empty string.
String coerceString(Object? v) => v?.toString() ?? '';

/// Coerce a JSON value to a String, preserving null (numbers become strings).
String? coerceStringOrNull(Object? v) => v?.toString();
