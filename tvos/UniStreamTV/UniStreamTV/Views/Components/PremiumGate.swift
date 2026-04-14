import SwiftUI

/// Wraps content and shows a locked overlay if the user lacks access.
struct PremiumGate<Content: View>: View {
    let feature: Feature
    @ViewBuilder let content: () -> Content

    @Environment(AppState.self) private var appState
    @State private var showPaywall = false

    private var hasAccess: Bool {
        FeatureAccess.canUse(feature, account: appState.authService.cachedAccountInfo)
    }

    var body: some View {
        ZStack {
            content()

            if !hasAccess {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 48))
                        .foregroundColor(Color(hex: 0x1B6B8A))

                    Text("Fonctionnalité Premium")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("Passez à Premium pour débloquer cette fonctionnalité.")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)

                    Button {
                        showPaywall = true
                    } label: {
                        Label("Voir les offres", systemImage: "crown")
                            .font(.headline)
                    }
                }
                .padding(40)
            }
        }
        .fullScreenCover(isPresented: $showPaywall) {
            SubscriptionView()
        }
    }
}

// MARK: - Imperative check

extension AppState {
    /// Imperative premium check — returns true if user has access.
    func checkPremiumAccess(_ feature: Feature) -> Bool {
        FeatureAccess.canUse(feature, account: authService.cachedAccountInfo)
    }
}
