import SwiftUI
import AuthenticationServices

/// Login screen — email/password + Apple Sign-In.
struct LoginView: View {
    @Environment(AppState.self) private var appState
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isSignUp = false
    @State private var error: String?
    @State private var isLoading = false

    var body: some View {
        ZStack {
            Color(hex: 0x0E0B1E).ignoresSafeArea()

            VStack(spacing: 40) {
                // Header
                VStack(spacing: 16) {
                    Image("Logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .shadow(color: Color(hex: 0x1B6B8A).opacity(0.4), radius: 16, y: 6)

                    Text("UniStream")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text(isSignUp ? "Créer un compte" : "Se connecter")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.7))
                }

                // Form
                VStack(spacing: 20) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()

                    SecureField("Mot de passe", text: $password)
                        .textContentType(isSignUp ? .newPassword : .password)

                    if isSignUp {
                        SecureField("Confirmer le mot de passe", text: $confirmPassword)
                            .textContentType(.newPassword)
                    }

                    if isSignUp && !password.isEmpty && password.count < 6 {
                        Text("Le mot de passe doit contenir au moins 6 caractères")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }

                    if isSignUp && !confirmPassword.isEmpty && password != confirmPassword {
                        Text("Les mots de passe ne correspondent pas")
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    Button(action: submit) {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text(isSignUp ? "Créer le compte" : "Se connecter")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(!isFormValid || isLoading)
                }
                .frame(maxWidth: 500)

                // Apple Sign-In
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.email, .fullName]
                } onCompletion: { result in
                    handleAppleSignIn(result)
                }
                .signInWithAppleButtonStyle(.white)
                .frame(width: 400, height: 50)

                // Toggle sign up / sign in
                Button(isSignUp ? "Déjà un compte ? Se connecter" : "Pas de compte ? Créer") {
                    isSignUp.toggle()
                    confirmPassword = ""
                    error = nil
                }
                .foregroundColor(Color(hex: 0x1B6B8A))

                // Error
                if let error {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.callout)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(60)
        }
    }

    private var isFormValid: Bool {
        guard !email.isEmpty, !password.isEmpty else { return false }
        if isSignUp {
            return password.count >= 6 && password == confirmPassword
        }
        return true
    }

    private func submit() {
        Task {
            isLoading = true
            error = nil
            do {
                if isSignUp {
                    try await appState.authService.signUp(email: email, password: password)
                }
                try await appState.authService.signIn(email: email, password: password)
                await appState.onSignIn()
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        Task {
            isLoading = true
            error = nil
            switch result {
            case .success(let auth):
                guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else {
                    error = "Invalid Apple credential"
                    isLoading = false
                    return
                }
                do {
                    try await appState.authService.signInWithApple(credential: credential)
                    await appState.onSignIn()
                } catch {
                    self.error = error.localizedDescription
                }
            case .failure(let err):
                if (err as? ASAuthorizationError)?.code != .canceled {
                    error = err.localizedDescription
                }
            }
            isLoading = false
        }
    }
}
