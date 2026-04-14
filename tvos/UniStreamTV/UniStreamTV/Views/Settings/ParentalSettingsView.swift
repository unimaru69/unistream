import SwiftUI

/// Parental control settings — PIN management + category blocking.
struct ParentalSettingsView: View {
    @Environment(AppState.self) private var appState

    @State private var pinInput = ""
    @State private var confirmPinInput = ""
    @State private var isSettingPin = false
    @State private var pinError: String?
    @State private var selectedTab = 0

    var body: some View {
        Group {
            if !appState.parentalService.isEnabled {
                setupView
            } else if !appState.parentalService.isUnlocked {
                lockedView
            } else {
                unlockedView
            }
        }
        .navigationTitle("Contrôle parental")
    }

    // MARK: - Setup (No PIN)

    private var setupView: some View {
        VStack(spacing: 30) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 60))
                .foregroundColor(Color(hex: 0x1B6B8A))

            Text("Protégez l'accès à certaines catégories")
                .font(.title3)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text("Un code PIN sera demandé pour accéder aux réglages et aux contenus bloqués.")
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 500)

            VStack(spacing: 16) {
                SecureField("Créer un PIN (4 chiffres)", text: $pinInput)
                    .keyboardType(.numberPad)
                    .frame(maxWidth: 300)

                SecureField("Confirmer le PIN", text: $confirmPinInput)
                    .keyboardType(.numberPad)
                    .frame(maxWidth: 300)

                if let error = pinError {
                    Text(error).font(.caption).foregroundColor(.red)
                }

                Button("Activer le contrôle parental") {
                    activatePin()
                }
                .disabled(pinInput.count < 4 || pinInput != confirmPinInput)
            }
        }
        .padding(60)
    }

    // MARK: - Locked

    private var lockedView: some View {
        VStack(spacing: 30) {
            Image(systemName: "lock.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("Contrôle parental activé")
                .font(.title3)
                .foregroundColor(.white)

            VStack(spacing: 16) {
                SecureField("Entrez le PIN", text: $pinInput)
                    .keyboardType(.numberPad)
                    .frame(maxWidth: 300)

                if let error = pinError {
                    Text(error).font(.caption).foregroundColor(.red)
                }

                Button("Déverrouiller") {
                    unlock()
                }
                .disabled(pinInput.isEmpty)
            }
        }
        .padding(60)
    }

    // MARK: - Unlocked (Category Management)

    private var unlockedView: some View {
        VStack(spacing: 0) {
            // Action buttons
            HStack(spacing: 20) {
                Button {
                    isSettingPin = true
                    pinInput = ""
                    confirmPinInput = ""
                } label: {
                    Label("Changer le PIN", systemImage: "key.fill")
                }

                Button(role: .destructive) {
                    appState.parentalService.clearPin()
                } label: {
                    Label("Désactiver", systemImage: "lock.open.fill")
                }

                Spacer()

                Text("\(appState.parentalService.totalBlockedCount) catégories bloquées")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 16)

            // Tab picker
            Picker("Type de contenu", selection: $selectedTab) {
                Text("Live").tag(0)
                Text("Films").tag(1)
                Text("Séries").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 40)
            .padding(.bottom, 16)

            // Category list
            categoryList(for: selectedTab)
        }
        .sheet(isPresented: $isSettingPin) {
            changePinSheet
        }
    }

    @ViewBuilder
    private func categoryList(for tab: Int) -> some View {
        let (categories, contentType): ([Category], ParentalService.ContentType) = switch tab {
        case 0: (appState.liveVM?.categories ?? [], .live)
        case 1: (appState.vodVM?.categories ?? [], .vod)
        default: (appState.seriesVM?.categories ?? [], .series)
        }

        if categories.isEmpty {
            VStack(spacing: 12) {
                ProgressView()
                Text("Chargement des catégories…").foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(categories) { category in
                let isBlocked = appState.parentalService.isCategoryBlocked(category.categoryId, contentType: contentType)
                Button {
                    appState.parentalService.toggleBlockedCategory(category.categoryId, contentType: contentType)
                } label: {
                    HStack {
                        Image(systemName: isBlocked ? "eye.slash.fill" : "eye.fill")
                            .foregroundColor(isBlocked ? .red : .green)
                            .frame(width: 30)
                        Text(category.categoryName)
                            .foregroundColor(.white)
                        Spacer()
                        if isBlocked {
                            Text("BLOQUÉE")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.2), in: Capsule())
                        }
                    }
                }
            }
        }
    }

    private var changePinSheet: some View {
        VStack(spacing: 24) {
            Text("Nouveau PIN").font(.title3).fontWeight(.bold)

            SecureField("Nouveau PIN (4 chiffres)", text: $pinInput)
                .keyboardType(.numberPad)
                .frame(maxWidth: 300)

            SecureField("Confirmer", text: $confirmPinInput)
                .keyboardType(.numberPad)
                .frame(maxWidth: 300)

            if let error = pinError {
                Text(error).font(.caption).foregroundColor(.red)
            }

            HStack(spacing: 20) {
                Button("Annuler") { isSettingPin = false }
                Button("Enregistrer") {
                    if pinInput.count >= 4 && pinInput == confirmPinInput {
                        appState.parentalService.setPin(pinInput)
                        isSettingPin = false
                    } else {
                        pinError = "Les PIN ne correspondent pas"
                    }
                }
                .disabled(pinInput.count < 4 || pinInput != confirmPinInput)
            }
        }
        .padding(40)
    }

    // MARK: - Actions

    private func activatePin() {
        guard pinInput.count >= 4 else {
            pinError = "Le PIN doit contenir au moins 4 chiffres"
            return
        }
        guard pinInput == confirmPinInput else {
            pinError = "Les PIN ne correspondent pas"
            return
        }
        appState.parentalService.setPin(pinInput)
        pinInput = ""
        confirmPinInput = ""
        pinError = nil
    }

    private func unlock() {
        if appState.parentalService.verifyPin(pinInput) {
            pinError = nil
            pinInput = ""
        } else {
            pinError = "PIN incorrect"
        }
    }
}
