import SwiftUI

/// Profile editor — view, edit, and delete IPTV profiles.
struct ProfileEditorView: View {
    @Environment(AppState.self) private var appState
    @State private var showDeleteConfirm = false
    @State private var profileToDelete: Profile?
    @State private var profileToEdit: Profile?
    @State private var showNewProfile = false
    @State private var pinProfile: Profile?
    @State private var pinAction: PinAction?

    private enum PinAction {
        case edit, delete
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 40) {
                ForEach(appState.profileManager.profiles) { profile in
                    profileCard(profile)
                }

                // Add new profile button
                Button {
                    showNewProfile = true
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(Color(hex: 0x1B6B8A))
                        Text("Ajouter un profil")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(30)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(Color(hex: 0x1B6B8A).opacity(0.4), style: StrokeStyle(lineWidth: 2, dash: [10]))
                    )
                }
                .buttonStyle(.card)

                // Server info
                if let active = appState.profileManager.activeProfile {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("INFORMATIONS SERVEUR")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)

                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                Image(systemName: "server.rack")
                                    .foregroundColor(Color(hex: 0x1B6B8A))
                                Text(active.serverUrl)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            HStack(spacing: 12) {
                                Image(systemName: "person.fill")
                                    .foregroundColor(Color(hex: 0x1B6B8A))
                                Text(active.username)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            .padding(60)
        }
        .navigationTitle("Profils")
        .sheet(item: $profileToEdit) { profile in
            ProfileEditSheet(profile: profile) { updated in
                appState.profileManager.updateProfile(updated)
                profileToEdit = nil
            } onCancel: {
                profileToEdit = nil
            }
        }
        .sheet(isPresented: $showNewProfile) {
            NewProfileSheet { newProfile in
                appState.profileManager.addProfile(newProfile)
                showNewProfile = false
            } onCancel: {
                showNewProfile = false
            }
        }
        .alert("Supprimer le profil ?", isPresented: $showDeleteConfirm) {
            Button("Annuler", role: .cancel) {}
            Button("Supprimer", role: .destructive) {
                if let profile = profileToDelete {
                    appState.profileManager.deleteProfile(profile)
                }
            }
        } message: {
            if let profile = profileToDelete {
                Text("Le profil « \(profile.name) » sera supprimé définitivement.")
            }
        }
        .fullScreenCover(item: $pinProfile) { profile in
            PinEntryView(
                profileName: profile.name,
                pinHash: profile.pinHash ?? ""
            ) {
                let action = pinAction
                pinProfile = nil
                switch action {
                case .edit:
                    profileToEdit = profile
                case .delete:
                    profileToDelete = profile
                    showDeleteConfirm = true
                case .none:
                    break
                }
            } onCancel: {
                pinProfile = nil
                pinAction = nil
            }
        }
    }

    // MARK: - Profile Card

    @ViewBuilder
    private func profileCard(_ profile: Profile) -> some View {
        let isActive = profile.id == appState.profileManager.activeProfile?.id

        VStack(spacing: 0) {
            HStack(spacing: 20) {
                Text(profile.avatar)
                    .font(.system(size: 50))

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        Text(profile.name)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        if isActive {
                            Text("ACTIF")
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 3)
                                .background(Color(hex: 0x1B6B8A), in: Capsule())
                                .foregroundColor(.white)
                        }
                    }

                    Text(profile.serverUrl)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)

                    Text("@\(profile.username)")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.4))
                }

                Spacer()
            }
            .padding(24)

            HStack(spacing: 20) {
                Button {
                    if profile.hasPin {
                        pinProfile = profile
                        pinAction = .edit
                    } else {
                        profileToEdit = profile
                    }
                } label: {
                    Label("Modifier", systemImage: "pencil")
                        .font(.callout)
                }

                if !isActive {
                    Button {
                        appState.profileManager.setActive(profile)
                    } label: {
                        Label("Activer", systemImage: "checkmark.circle")
                            .font(.callout)
                    }
                    .tint(Color(hex: 0x1B6B8A))
                }

                if appState.profileManager.profiles.count > 1 {
                    Button(role: .destructive) {
                        if profile.hasPin {
                            pinProfile = profile
                            pinAction = .delete
                        } else {
                            profileToDelete = profile
                            showDeleteConfirm = true
                        }
                    } label: {
                        Label("Supprimer", systemImage: "trash")
                            .font(.callout)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(isActive ? 0.08 : 0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(
                            isActive ? Color(hex: 0x1B6B8A).opacity(0.5) : Color.clear,
                            lineWidth: 2
                        )
                )
        )
    }
}

// MARK: - Edit Sheet

/// Separate view that initializes @State directly from the profile.
/// This ensures fields are pre-filled correctly when the sheet opens.
private struct ProfileEditSheet: View {
    let profile: Profile
    let onSave: (Profile) -> Void
    let onCancel: () -> Void

    // Initialize @State from profile — this works because SwiftUI
    // initializes @State once when the view is first created.
    @State private var name: String
    @State private var serverUrl: String
    @State private var username: String
    @State private var password: String
    @State private var avatar: String

    private let avatars = ["👤", "👨", "👩", "👦", "👧", "🧑", "👴", "👵", "🦸", "🧙", "🎮", "📺"]

    init(profile: Profile, onSave: @escaping (Profile) -> Void, onCancel: @escaping () -> Void) {
        self.profile = profile
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: profile.name)
        _serverUrl = State(initialValue: profile.serverUrl)
        _username = State(initialValue: profile.username)
        _password = State(initialValue: profile.password)
        _avatar = State(initialValue: profile.avatar)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 40) {
                    // Current preview
                    HStack(spacing: 16) {
                        Text(avatar)
                            .font(.system(size: 60))
                        VStack(alignment: .leading) {
                            Text(name.isEmpty ? "Sans nom" : name)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Text(serverUrl)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.bottom, 10)

                    // Avatar picker
                    VStack(alignment: .leading, spacing: 16) {
                        Text("AVATAR")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 20)], spacing: 20) {
                            ForEach(avatars, id: \.self) { emoji in
                                Button {
                                    avatar = emoji
                                } label: {
                                    Text(emoji)
                                        .font(.system(size: 48))
                                        .frame(width: 90, height: 90)
                                        .background(
                                            avatar == emoji
                                                ? Color(hex: 0x1B6B8A).opacity(0.4)
                                                : Color.white.opacity(0.08),
                                            in: RoundedRectangle(cornerRadius: 18)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18)
                                                .strokeBorder(
                                                    avatar == emoji
                                                        ? Color(hex: 0x1B6B8A)
                                                        : Color.clear,
                                                    lineWidth: 3
                                                )
                                        )
                                }
                                .buttonStyle(.card)
                            }
                        }
                    }

                    // Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("NOM DU PROFIL")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Nom du profil", text: $name)
                    }

                    // Server fields
                    VStack(alignment: .leading, spacing: 16) {
                        Text("SERVEUR IPTV")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        TextField("URL du serveur", text: $serverUrl)
                            .autocorrectionDisabled()

                        TextField("Nom d'utilisateur", text: $username)
                            .autocorrectionDisabled()

                        SecureField("Mot de passe", text: $password)
                    }
                }
                .padding(60)
            }
            .navigationTitle("Modifier « \(profile.name) »")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        let updated = Profile(
                            id: profile.id,
                            name: name.trimmingCharacters(in: .whitespaces),
                            serverUrl: serverUrl.trimmingCharacters(in: .whitespaces),
                            username: username.trimmingCharacters(in: .whitespaces),
                            password: password,
                            avatar: avatar,
                            pinHash: profile.pinHash
                        )
                        onSave(updated)
                    }
                    .disabled(name.isEmpty || serverUrl.isEmpty || username.isEmpty || password.isEmpty)
                }
            }
        }
    }
}

// MARK: - New Profile Sheet

private struct NewProfileSheet: View {
    let onSave: (Profile) -> Void
    let onCancel: () -> Void

    @State private var name = ""
    @State private var serverUrl = ""
    @State private var username = ""
    @State private var password = ""
    @State private var avatar = "👤"

    private let avatars = ["👤", "👨", "👩", "👦", "👧", "🧑", "👴", "👵", "🦸", "🧙", "🎮", "📺"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 40) {
                    // Avatar picker
                    VStack(alignment: .leading, spacing: 16) {
                        Text("AVATAR")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 20)], spacing: 20) {
                            ForEach(avatars, id: \.self) { emoji in
                                Button {
                                    avatar = emoji
                                } label: {
                                    Text(emoji)
                                        .font(.system(size: 48))
                                        .frame(width: 90, height: 90)
                                        .background(
                                            avatar == emoji
                                                ? Color(hex: 0x1B6B8A).opacity(0.4)
                                                : Color.white.opacity(0.08),
                                            in: RoundedRectangle(cornerRadius: 18)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18)
                                                .strokeBorder(
                                                    avatar == emoji
                                                        ? Color(hex: 0x1B6B8A)
                                                        : Color.clear,
                                                    lineWidth: 3
                                                )
                                        )
                                }
                                .buttonStyle(.card)
                            }
                        }
                    }

                    // Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("NOM DU PROFIL")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Ex: Mon serveur", text: $name)
                    }

                    // Server fields
                    VStack(alignment: .leading, spacing: 16) {
                        Text("SERVEUR IPTV")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        TextField("http://serveur.com:port", text: $serverUrl)
                            .autocorrectionDisabled()

                        TextField("Nom d'utilisateur", text: $username)
                            .autocorrectionDisabled()

                        SecureField("Mot de passe", text: $password)
                    }
                }
                .padding(60)
            }
            .navigationTitle("Nouveau profil")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Créer") {
                        let profile = Profile(
                            name: name.trimmingCharacters(in: .whitespaces),
                            serverUrl: serverUrl.trimmingCharacters(in: .whitespaces),
                            username: username.trimmingCharacters(in: .whitespaces),
                            password: password,
                            avatar: avatar
                        )
                        onSave(profile)
                    }
                    .disabled(name.isEmpty || serverUrl.isEmpty || username.isEmpty || password.isEmpty)
                }
            }
        }
    }
}
