import Foundation

/// The signed-in user's row in `user_accounts` — mirrors Flutter's
/// `AccountInfo`.
///
/// The table still carries trial and subscription columns from the
/// abandoned paid model; the app no longer reads them. Every feature is
/// available to every account.
struct AccountInfo: Codable, Identifiable {
    let id: String
    var email: String
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case createdAt = "created_at"
    }

    init(id: String, email: String = "", createdAt: Date? = nil) {
        self.id = id
        self.email = email
        self.createdAt = createdAt
    }
}
