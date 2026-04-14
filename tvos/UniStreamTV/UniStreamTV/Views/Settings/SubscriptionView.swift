import SwiftUI
import RevenueCat

/// Paywall screen — mirrors Flutter's `PaywallScreen`.
struct SubscriptionView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var isAnnual = true
    @State private var purchaseError: String?
    @State private var showRestoreSuccess = false

    private var purchaseService: PurchaseService { appState.purchaseService }

    private var packages: [Package] {
        guard let offering = purchaseService.offerings?.current else { return [] }
        return offering.availablePackages.filter { pkg in
            if isAnnual {
                return pkg.packageType == .annual
            } else {
                return pkg.packageType == .monthly
            }
        }
    }

    var body: some View {
        ZStack {
            Color(hex: 0x0E0B1E).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 40) {
                    // Header
                    headerSection

                    // Feature comparison
                    featureTable

                    // Billing toggle
                    billingToggle

                    // Package buttons
                    packageButtons

                    // Restore
                    restoreButton

                    // Close
                    Button("Fermer", role: .cancel) { dismiss() }
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.bottom, 40)
                }
                .padding(60)
            }

            // Loading overlay
            if purchaseService.isLoading {
                Color.black.opacity(0.5).ignoresSafeArea()
                ProgressView()
                    .scaleEffect(1.5)
            }
        }
        .task {
            await purchaseService.fetchOfferings()
        }
        .alert("Achats restaurés", isPresented: $showRestoreSuccess) {
            Button("OK") { dismiss() }
        } message: {
            Text("Vos achats ont été restaurés avec succès.")
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "crown.fill")
                .font(.system(size: 50))
                .foregroundColor(.yellow)

            Text("UniStream Premium")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text("Débloquez toutes les fonctionnalités")
                .font(.headline)
                .foregroundColor(.white.opacity(0.7))
        }
    }

    private var featureTable: some View {
        VStack(spacing: 0) {
            // Header row
            HStack {
                Text("Fonctionnalité")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Basic")
                    .frame(width: 100)
                Text("Premium")
                    .frame(width: 100)
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(Color.white.opacity(0.1))

            // Feature rows
            featureRow("Live TV", basic: true, premium: true)
            featureRow("Films & Séries", basic: true, premium: true)
            featureRow("Favoris", basic: true, premium: true)
            featureRow("Sync cloud", basic: true, premium: true)
            featureRow("Collections", basic: false, premium: true)
            featureRow("Multi-profils", basic: false, premium: true)
            featureRow("Contrôle parental", basic: false, premium: true)
            featureRow("Catch-up / Replay", basic: false, premium: true)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .frame(maxWidth: 700)
    }

    private func featureRow(_ name: String, basic: Bool, premium: Bool) -> some View {
        HStack {
            Text(name)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: basic ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundColor(basic ? .green : .white.opacity(0.3))
                .frame(width: 100)
            Image(systemName: premium ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundColor(premium ? .green : .white.opacity(0.3))
                .frame(width: 100)
        }
        .font(.body)
        .foregroundColor(.white.opacity(0.9))
        .padding(.vertical, 10)
        .padding(.horizontal, 20)
        .background(Color.white.opacity(0.05))
    }

    private var billingToggle: some View {
        HStack(spacing: 20) {
            Button {
                isAnnual = false
            } label: {
                Text("Mensuel")
                    .fontWeight(isAnnual ? .regular : .bold)
                    .foregroundColor(isAnnual ? .white.opacity(0.6) : .white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
            }

            Button {
                isAnnual = true
            } label: {
                HStack(spacing: 8) {
                    Text("Annuel")
                        .fontWeight(isAnnual ? .bold : .regular)
                    Text("-17%")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.yellow)
                        .clipShape(Capsule())
                }
                .foregroundColor(isAnnual ? .white : .white.opacity(0.6))
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
            }
        }
    }

    private var packageButtons: some View {
        VStack(spacing: 16) {
            if packages.isEmpty && !purchaseService.isLoading {
                Text("Offres non disponibles")
                    .foregroundColor(.white.opacity(0.5))
            }

            ForEach(packages, id: \.identifier) { package in
                Button {
                    Task { await purchase(package) }
                } label: {
                    VStack(spacing: 6) {
                        Text(package.storeProduct.localizedTitle)
                            .font(.headline)
                        Text(package.localizedPriceString)
                            .font(.title3)
                            .fontWeight(.bold)
                        if let intro = package.storeProduct.introductoryDiscount {
                            Text("Essai gratuit \(intro.subscriptionPeriod.value) \(periodUnit(intro.subscriptionPeriod.unit))")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .frame(maxWidth: 500)
                    .padding(.vertical, 16)
                }
                .tint(package.identifier.contains("premium") ? Color(hex: 0x1B6B8A) : .gray)
            }

            if let error = purchaseError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.callout)
            }
        }
    }

    private var restoreButton: some View {
        Button("Restaurer mes achats") {
            Task {
                let success = await purchaseService.restorePurchases()
                if success {
                    // Refresh account info from Supabase
                    _ = await appState.authService.fetchAccountInfo()
                    showRestoreSuccess = true
                } else {
                    purchaseError = purchaseService.error ?? "Aucun achat trouvé"
                }
            }
        }
        .foregroundColor(Color(hex: 0x1B6B8A))
    }

    // MARK: - Actions

    private func purchase(_ package: Package) async {
        purchaseError = nil
        let success = await purchaseService.purchase(package: package)
        if success {
            // Refresh account info from Supabase (webhook updates tier)
            _ = await appState.authService.fetchAccountInfo()
            dismiss()
        } else if let err = purchaseService.error {
            purchaseError = err
        }
    }

    private func periodUnit(_ unit: SubscriptionPeriod.Unit) -> String {
        switch unit {
        case .day: "jours"
        case .week: "semaines"
        case .month: "mois"
        case .year: "ans"
        @unknown default: ""
        }
    }
}
