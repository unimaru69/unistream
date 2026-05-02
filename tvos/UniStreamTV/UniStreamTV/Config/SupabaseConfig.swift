import Foundation
import CryptoKit
@preconcurrency import Supabase

/// Supabase configuration — mirrors Flutter's `supabase_config.dart`.
enum SupabaseConfig {
    static let url = URL(string: "https://aslqfsoyhjuomfxopsvs.supabase.co")!
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFzbHFmc295aGp1b21meG9wc3ZzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzUzNDUxODEsImV4cCI6MjA5MDkyMTE4MX0.UdfG1MJmVrGLHgdqT3uYbOKJKJnUcnTWW-z7Qq1WmyI"

    /// Shared Supabase client (lazy-initialized).
    static let client = SupabaseClient(supabaseURL: url, supabaseKey: anonKey)

    /// Compute SHA-256 profile hash — must match Flutter's `computeProfileHash`.
    static func profileHash(serverUrl: String, username: String) -> String {
        let input = "\(serverUrl):\(username)"
        let hash = SHA256.hash(data: Data(input.utf8))
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    /// Current authenticated user ID.
    static var currentUserId: String? {
        client.auth.currentUser?.id.uuidString
    }
}
