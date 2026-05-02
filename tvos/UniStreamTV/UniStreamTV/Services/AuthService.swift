import Foundation
// @preconcurrency disables Swift 6 strict-concurrency checks on the
// Supabase types we touch here. The Postgrest response types still
// aren't fully marked Sendable as of supabase-swift 2.x, so without
// this the GitHub macos-latest runner (Xcode 26 / Swift 6) refuses
// to compile `try await client.from(...).execute().value` with
// "non-sendable result type ... cannot be sent from nonisolated
// context". Local Xcode used to default-tolerate this, GitHub's no
// longer does.
@preconcurrency import Supabase
import AuthenticationServices
import os

/// Supabase auth service — mirrors Flutter's `auth_service.dart`.
@MainActor @Observable
final class AuthService {
    private let logger = Logger(subsystem: "fr.unimaru.unistream.tv", category: "Auth")
    private let client = SupabaseConfig.client

    private(set) var cachedAccountInfo: AccountInfo?
    private(set) var isLoading = false

    // MARK: - Session

    var currentUser: User? { client.auth.currentUser }
    var userId: String? { currentUser?.id.uuidString }
    var isAuthenticated: Bool { client.auth.currentSession != nil }

    // MARK: - Sign In

    func signIn(email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }

        _ = try await client.auth.signIn(email: email, password: password)
        logger.info("Signed in: \(email)")
    }

    // MARK: - Sign Up

    func signUp(email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }

        _ = try await client.auth.signUp(email: email, password: password)
        logger.info("Signed up: \(email)")
    }

    // MARK: - Sign In with Apple

    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws {
        isLoading = true
        defer { isLoading = false }

        guard let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8)
        else {
            throw AuthError.missingAppleToken
        }

        _ = try await client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken)
        )
        logger.info("Signed in with Apple")
    }

    // MARK: - Sign Out

    func signOut() async throws {
        try await client.auth.signOut()
        cachedAccountInfo = nil
        logger.info("Signed out")
    }

    // MARK: - Account Info

    /// Fetch user account info from `user_accounts` table.
    func fetchAccountInfo() async -> AccountInfo? {
        guard let uid = userId else { return nil }

        do {
            let rows: [AccountInfo] = try await client
                .from("user_accounts")
                .select()
                .eq("id", value: uid)
                .limit(1)
                .execute()
                .value
            let response = rows.first

            cachedAccountInfo = response
            return response
        } catch {
            logger.warning("fetchAccountInfo failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Claim Orphaned Data

    /// Link pre-auth data to the current user via profile hash.
    func claimProfileData(profileHash: String) async {
        do {
            try await client.rpc("claim_profile_data", params: ["p_profile_hash": profileHash]).execute()
            logger.info("Claimed profile data for hash: \(profileHash.prefix(8))…")
        } catch {
            logger.warning("claimProfileData failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Delete Account

    func deleteAccount() async throws {
        guard let session = client.auth.currentSession else { return }

        let response = try await client.functions.invoke(
            "delete-user",
            options: .init(headers: ["Authorization": "Bearer \(session.accessToken)"])
        )
        // Edge function returns raw bytes
        _ = response

        try await client.auth.signOut()
        cachedAccountInfo = nil
        logger.info("Account deleted")
    }
}

// MARK: - Error Types

enum AuthError: LocalizedError {
    case missingAppleToken

    var errorDescription: String? {
        switch self {
        case .missingAppleToken: "Apple Sign-In token missing"
        }
    }
}
