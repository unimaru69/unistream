import SwiftUI
import Kingfisher

/// tvOS EPG — category picker → channel list → channel detail with programs.
struct EPGView: View {
    @Environment(AppState.self) private var appState

    let channels: [Channel]
    let categoryNames: [String: String]

    @State private var selectedCategoryId: String?
    @State private var epgViewModel: EPGViewModel?

    /// Categories derived from channels.
    private var categories: [(id: String, name: String, count: Int)] {
        var dict: [String: Int] = [:]
        for ch in channels {
            let catId = ch.categoryId ?? "other"
            dict[catId, default: 0] += 1
        }
        return dict.map { (id: $0.key, name: categoryNames[$0.key] ?? "Autre", count: $0.value) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Channels for current category.
    private var filteredChannels: [Channel] {
        guard let catId = selectedCategoryId else { return [] }
        if catId == "__favorites__" {
            let favIds = Set(appState.syncService.favorites.values
                .filter { $0.mode == "live" }
                .compactMap { $0.streamId })
            return channels.filter { favIds.contains($0.streamId) }
        }
        return channels.filter { $0.categoryId == catId }
    }

    var body: some View {
        Group {
            if selectedCategoryId == nil {
                categoryPicker
            } else {
                channelListView
            }
        }
        .navigationTitle("Guide des programmes")
    }

    // MARK: - Category Picker

    private var categoryPicker: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Choisissez une catégorie")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 50)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 340, maximum: 460), spacing: 30)], spacing: 30) {
                    // Favorites entry
                    let favCount = appState.syncService.favorites.values.filter { $0.mode == "live" }.count
                    if favCount > 0 {
                        Button { selectedCategoryId = "__favorites__" } label: {
                            epgCategoryCard(name: "Favoris", count: favCount, icon: "heart.fill", color: .yellow)
                        }
                        .buttonStyle(.tvCard)
                    }

                    ForEach(Array(categories.enumerated()), id: \.element.id) { index, cat in
                        Button { selectedCategoryId = cat.id } label: {
                            epgCategoryCard(name: cat.name, count: cat.count, icon: categoryIcon(cat.name), color: categoryColor(index))
                        }
                        .buttonStyle(.tvCard)
                    }
                }
                .padding(.horizontal, 50)
            }
            .padding(.vertical, 30)
        }
    }

    @ViewBuilder
    private func epgCategoryCard(name: String, count: Int, icon: String, color: Color) -> some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient(colors: [color.opacity(0.4), color.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: icon)
                    .font(.system(size: 36))
                    .foregroundColor(color)
            }
            .frame(height: 110)

            HStack {
                Text(name).font(.body).fontWeight(.medium).foregroundColor(.white).lineLimit(2)
                Spacer()
                Text("\(count) ch.").font(.caption).foregroundColor(.white.opacity(0.5))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(height: 60)
        }
        .frame(height: 170)
    }

    // MARK: - Channel List

    private var channelListView: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    selectedCategoryId = nil
                    epgViewModel = nil
                } label: {
                    Label("Catégories", systemImage: "chevron.left").font(.callout)
                }
                Spacer()
                if let vm = epgViewModel, vm.isLoading {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("\(vm.loadedCount)/\(vm.totalCount)").font(.caption).foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 12)

            List(filteredChannels, id: \.streamId) { channel in
                NavigationLink(value: channel) {
                    HStack(spacing: 12) {
                        KFImage(URL(string: channel.displayIcon))
                            .resizable()
                            .placeholder {
                                Image(systemName: "tv").foregroundColor(.gray).frame(width: 44, height: 44)
                            }
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(channel.name)
                                .font(.callout).fontWeight(.medium).foregroundColor(.white).lineLimit(1)

                            if let prog = epgViewModel?.currentProgram(for: channel.streamId) {
                                HStack(spacing: 4) {
                                    Circle().fill(Color.red).frame(width: 5, height: 5)
                                    Text(prog.title).font(.caption2).foregroundColor(Color(hex: 0x1B6B8A)).lineLimit(1)
                                }
                            }
                        }

                        Spacer()

                        if channel.hasCatchup {
                            Text("REPLAY")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(Color.orange, in: Capsule())
                        }
                    }
                }
            }
        }
        .navigationDestination(for: Channel.self) { channel in
            ChannelDetailView(channel: channel, allChannels: filteredChannels)
        }
        .task(id: selectedCategoryId) {
            let vm = EPGViewModel(api: appState.api)
            epgViewModel = vm
            await vm.loadEPG(for: filteredChannels)
        }
    }

    // MARK: - Helpers

    private func categoryIcon(_ name: String) -> String {
        let l = name.lowercased()
        if l.contains("sport") { return "sportscourt.fill" }
        if l.contains("news") || l.contains("info") || l.contains("actual") { return "newspaper.fill" }
        if l.contains("film") || l.contains("ciné") || l.contains("movie") { return "film.fill" }
        if l.contains("music") || l.contains("musique") { return "music.note.tv.fill" }
        if l.contains("enfant") || l.contains("kid") { return "figure.and.child.holdinghands" }
        if l.contains("document") || l.contains("découverte") { return "globe.europe.africa.fill" }
        return "folder.fill"
    }

    private let colorPalette: [Color] = [.teal, .blue, .purple, .green, .orange, .pink, .red, .indigo, .mint, .cyan]

    private func categoryColor(_ index: Int) -> Color {
        colorPalette[index % colorPalette.count]
    }
}
