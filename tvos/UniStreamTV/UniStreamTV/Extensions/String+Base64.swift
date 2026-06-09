import Foundation

extension String {
    /// Attempt Base64 decode (used for EPG titles). Returns self on failure.
    var base64Decoded: String {
        guard let data = Data(base64Encoded: self),
              let decoded = String(data: data, encoding: .utf8)
        else { return self }
        return decoded
    }
}

// MARK: - JSON value coercion
//
// Xtream panels are inconsistent across servers: some return id/text fields
// like `category_id` or `rating` as strings ("8.5"), others as JSON numbers
// (8.5). A plain `as? String` cast silently yields nil on the numeric form,
// dropping the value. These helpers normalise any scalar JSON value to a
// String — the Swift mirror of Flutter's `coerceString` / `coerceStringOrNull`.
// `JSONSerialization` maps a JSON null to `NSNull`, which is handled as nil.

/// Coerce a JSON value to a String, preserving null (numbers become strings).
func coerceStringOrNull(_ value: Any?) -> String? {
    guard let value, !(value is NSNull) else { return nil }
    if let s = value as? String { return s }
    if let n = value as? NSNumber { return n.stringValue }
    return String(describing: value)
}

/// Coerce a JSON value to a non-null String. Null becomes the empty string.
func coerceString(_ value: Any?) -> String {
    coerceStringOrNull(value) ?? ""
}
