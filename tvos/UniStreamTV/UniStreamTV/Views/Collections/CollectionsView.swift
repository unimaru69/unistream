import SwiftUI
import Kingfisher

/// Collections management screen — list, create, browse custom collections.
struct CollectionsView: View {
    @Environment(AppState.self) private var appState
    @State private var showCreateDialog = false
    @State private var newCollectionName = ""

    var body: some View {
        Group {
            if appState.collectionsService.collections.isEmpty {
                emptyState
            } else {
                collectionsList
            }
        }
        .navigationTitle("Collections")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    newCollectionName = ""
                    showCreateDialog = true
                } label: {
                    Label("Nouvelle collection", systemImage: "plus")
                }
            }
        }
        .alert("Nouvelle collection", isPresented: $showCreateDialog) {
            TextField("Nom de la collection", text: $newCollectionName)
            Button("Créer") {
                if !newCollectionName.trimmingCharacters(in: .whitespaces).isEmpty {
                    _ = appState.collectionsService.createCollection(name: newCollectionName)
                }
            }
            Button("Annuler", role: .cancel) {}
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(Color(hex: 0x1B6B8A).opacity(0.4))

            Text("Aucune collection")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text("Créez des collections pour organiser vos contenus favoris")
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            Button {
                newCollectionName = ""
                showCreateDialog = true
            } label: {
                Label("Créer une collection", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var collectionsList: some View {
        List {
            ForEach(appState.collectionsService.collections) { collection in
                NavigationLink(value: collection) {
                    HStack(spacing: 16) {
                        // Thumbnail mosaic
                        collectionThumbnail(collection)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(collection.name)
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)

                            Text("\(collection.items.count) élément\(collection.items.count > 1 ? "s" : "")")
                                .font(.caption)
                                .foregroundColor(.gray)

                            if let mode = collection.mode {
                                Text(modeLabel(mode))
                                    .font(.caption2)
                                    .foregroundColor(Color(hex: 0x1B6B8A))
                            }
                        }

                        Spacer()
                    }
                }
                .contextMenu {
                    Button(role: .destructive) {
                        appState.collectionsService.deleteCollection(id: collection.id)
                    } label: {
                        Label("Supprimer", systemImage: "trash")
                    }
                }
            }
        }
        .navigationDestination(for: CollectionData.self) { collection in
            CollectionDetailView(collection: collection)
        }
    }

    @ViewBuilder
    private func collectionThumbnail(_ collection: CollectionData) -> some View {
        let items = Array(collection.items.prefix(4))

        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: 0x161230))
                .frame(width: 60, height: 60)

            if items.isEmpty {
                Image(systemName: "folder.fill")
                    .foregroundColor(.gray)
            } else if items.count == 1 {
                KFImage(URL(string: items[0].displayIcon))
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                // 2x2 grid
                let size: CGFloat = 28
                LazyVGrid(columns: [GridItem(.fixed(size)), GridItem(.fixed(size))], spacing: 2) {
                    ForEach(items.prefix(4), id: \.key) { item in
                        KFImage(URL(string: item.displayIcon))
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size, height: size)
                            .clipped()
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .frame(width: 60, height: 60)
    }

    private func modeLabel(_ mode: String) -> String {
        switch mode {
        case "live": "Chaînes"
        case "movie": "Films"
        case "series": "Séries"
        default: mode
        }
    }
}

/// Detail view for a single collection.
struct CollectionDetailView: View {
    @Environment(AppState.self) private var appState
    let collection: CollectionData

    private var currentCollection: CollectionData? {
        appState.collectionsService.collections.first { $0.id == collection.id }
    }

    var body: some View {
        Group {
            if let col = currentCollection, !col.items.isEmpty {
                List(col.items, id: \.key) { item in
                    Button {
                        playItem(item)
                    } label: {
                        HStack(spacing: 16) {
                            KFImage(URL(string: item.displayIcon))
                                .resizable()
                                .placeholder {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color(hex: 0x161230))
                                        .frame(width: 50, height: 50)
                                }
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 50, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 6))

                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.name)
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .lineLimit(1)

                                Text(modeLabel(item.mode))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }

                            Spacer()

                            Image(systemName: "play.circle.fill")
                                .foregroundColor(Color(hex: 0x1B6B8A))
                        }
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            appState.collectionsService.removeFromCollection(
                                collectionId: collection.id,
                                itemKey: item.key
                            )
                        } label: {
                            Label("Retirer", systemImage: "minus.circle")
                        }
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "folder")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.3))
                    Text("Collection vide")
                        .foregroundColor(.gray)
                    Text("Ajoutez des contenus depuis les écrans Films, Séries ou Live")
                        .foregroundColor(.gray.opacity(0.6))
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(collection.name)
    }

    private func playItem(_ item: FavoriteItem) {
        switch item.mode {
        case "live":
            if let sid = item.streamId, let url = appState.api.liveStreamUrl(streamId: sid) {
                PlayerPresenter.playLive(url: url, title: item.name, contentKey: "live_\(sid)")
            }
        case "movie":
            if let sid = item.streamId,
               let url = appState.api.vodStreamUrl(streamId: sid, extension: item.containerExtension ?? "mp4") {
                PlayerPresenter.playVOD(url: url, title: item.name, contentKey: "vod_\(sid)")
            }
        default:
            break
        }
    }

    private func modeLabel(_ mode: String) -> String {
        switch mode {
        case "live": "Chaîne"
        case "movie": "Film"
        case "series": "Série"
        default: mode
        }
    }
}
