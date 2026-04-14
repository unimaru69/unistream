import SwiftUI

/// Universal search across Live, VOD, and Series.
struct SearchView: View {
    @Environment(AppState.self) private var appState
    @State private var searchVM: SearchViewModel?

    var body: some View {
        NavigationStack {
            VStack {
                if let vm = searchVM {
                    SearchContentView(viewModel: vm, api: appState.api)
                } else {
                    ProgressView("Chargement…")
                }
            }
            .navigationTitle("Recherche")
            .navigationDestination(for: SeriesItem.self) { series in
                if let seriesVM = appState.seriesVM {
                    SeriesDetailView(series: series, viewModel: seriesVM, api: appState.api)
                }
            }
            .navigationDestination(for: VodItem.self) { vod in
                VODDetailView(item: vod, api: appState.api)
            }
        }
        .task {
            if searchVM == nil {
                let vm = SearchViewModel(api: appState.api)
                vm.syncService = appState.syncService
                searchVM = vm
                await vm.preload()
            }
        }
    }
}

struct SearchContentView: View {
    @Bindable var viewModel: SearchViewModel
    let api: XtreamAPIService

    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 20) {
            // Search field
            HStack(spacing: 16) {
                TextField("Rechercher…", text: $viewModel.query)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    .onSubmit {
                        viewModel.commitSearch()
                    }
                    .onChange(of: viewModel.query) {
                        viewModel.search()
                    }
            }
            .padding(.horizontal, 60)

            // Filter picker (only when there's a query)
            if !viewModel.query.isEmpty {
                HStack(spacing: 12) {
                    ForEach(SearchFilter.allCases) { filter in
                        Button {
                            viewModel.activeFilter = filter
                            viewModel.search()
                        } label: {
                            Label(filter.rawValue, systemImage: filter.icon)
                                .font(.caption)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    viewModel.activeFilter == filter
                                        ? Color(hex: 0x1B6B8A)
                                        : Color.white.opacity(0.1),
                                    in: Capsule()
                                )
                                .foregroundColor(viewModel.activeFilter == filter ? .white : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if viewModel.isSearching {
                ProgressView()
            } else if viewModel.query.isEmpty {
                // Show search history when query is empty
                if !viewModel.searchHistory.isEmpty {
                    searchHistoryView
                } else {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.3))
                        Text("Recherchez parmi les chaînes, films et séries")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            } else if viewModel.channels.isEmpty && viewModel.vodItems.isEmpty && viewModel.seriesItems.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.3))
                    Text("Aucun résultat pour « \(viewModel.query) »")
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                List {
                    // Live channels
                    if !viewModel.channels.isEmpty {
                        Section("Live (\(viewModel.channels.count))") {
                            ForEach(viewModel.channels.prefix(20)) { ch in
                                Button {
                                    viewModel.commitSearch()
                                    guard let url = appState.api.liveStreamUrl(streamId: ch.streamId) else { return }
                                    PlayerPresenter.playLive(url: url, title: ch.name, contentKey: "live_\(ch.streamId)")
                                } label: {
                                    Label(ch.name, systemImage: "tv")
                                }
                            }
                        }
                    }

                    // VOD
                    if !viewModel.vodItems.isEmpty {
                        Section("Films (\(viewModel.vodItems.count))") {
                            ForEach(viewModel.vodItems.prefix(20)) { vod in
                                NavigationLink(value: vod) {
                                    HStack {
                                        Label(vod.name, systemImage: "film")
                                        Spacer()
                                        watchBadge(for: "vod_\(vod.streamId)")
                                    }
                                }
                                .simultaneousGesture(TapGesture().onEnded {
                                    viewModel.commitSearch()
                                })
                            }
                        }
                    }

                    // Series
                    if !viewModel.seriesItems.isEmpty {
                        Section("Séries (\(viewModel.seriesItems.count))") {
                            ForEach(viewModel.seriesItems.prefix(20)) { series in
                                NavigationLink(value: series) {
                                    HStack {
                                        Label(series.name, systemImage: "tv.inset.filled")
                                        Spacer()
                                        watchBadge(for: "series_\(series.seriesId)")
                                    }
                                }
                                .simultaneousGesture(TapGesture().onEnded {
                                    viewModel.commitSearch()
                                })
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Search History

    private var searchHistoryView: some View {
        List {
            Section {
                HStack {
                    Text("Recherches récentes")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Button("Effacer") {
                        viewModel.clearHistory()
                    }
                    .font(.caption)
                    .foregroundColor(Color(hex: 0x1B6B8A))
                }
            }

            ForEach(viewModel.searchHistory, id: \.self) { item in
                Button {
                    viewModel.selectHistoryItem(item)
                } label: {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(.secondary)
                        Text(item)
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: "arrow.up.left")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Watch Status Badge

    @ViewBuilder
    private func watchBadge(for key: String) -> some View {
        if let entry = appState.syncService.getProgress(contentKey: key) {
            if entry.progress > 0.95 {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            } else {
                Text("\(Int(entry.progress * 100))%")
                    .font(.caption2)
                    .foregroundColor(Color(hex: 0x1B6B8A))
            }
        }
    }
}
