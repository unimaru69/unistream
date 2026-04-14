import Foundation

/// IPTV server profile — mirrors Flutter's `Profile`.
struct Profile: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var serverUrl: String
    var username: String
    var password: String
    var avatar: String
    var pinHash: String?

    var hasPin: Bool { pinHash != nil && !(pinHash?.isEmpty ?? true) }

    /// Profile hash for Supabase sync (must match Flutter).
    var profileHash: String {
        SupabaseConfig.profileHash(serverUrl: serverUrl, username: username)
    }

    init(
        id: String = UUID().uuidString,
        name: String,
        serverUrl: String,
        username: String,
        password: String,
        avatar: String = "👤",
        pinHash: String? = nil
    ) {
        self.id = id
        self.name = name
        self.serverUrl = serverUrl
        self.username = username
        self.password = password
        self.avatar = avatar
        self.pinHash = pinHash
    }
}
