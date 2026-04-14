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
