import Foundation
import os

/// Manages Series categories, series lists, and episode loading.
@MainActor @Observable
final class SeriesViewModel {
    private let logger = Logger(subsystem: "fr.unimaru.unistream.tv", category: "Series")

    private(set) var categories: [Category] = []
    private(set) var items: [SeriesItem] = []
    private(set) var episodes: [String: [Episode]] = [:]  // season → episodes
    var isLoadingCategories = false
    var isLoadingItems = false
    var isLoadingEpisodes = false
    var error: String?

    /// Category the grid is currently showing — see `LiveViewModel`.
    private(set) var currentCategory: Category?

    private let api: XtreamAPIService

    init(api: XtreamAPIService) {
        self.api = api
    }

    func loadCategories() async {
        isLoadingCategories = true
        error = nil
        do {
            categories = try await api.getSeriesCategories()
            logger.info("Loaded \(self.categories.count) series categories")
        } catch {
            self.error = error.localizedDescription
        }
        isLoadingCategories = false
    }

    func loadItems(for category: Category, force: Bool = false) async {
        isLoadingItems = true
        error = nil
        currentCategory = category
        items = []
        do {
            items = try await api.getSeries(categoryId: category.categoryId, force: force)
            logger.info("Loaded \(self.items.count) series")
        } catch {
            self.error = error.localizedDescription
        }
        isLoadingItems = false
    }

    /// Re-pull the currently displayed lists — see `LiveViewModel`.
    func reloadAfterCatalogRefresh() async {
        if !categories.isEmpty {
            await loadCategories()
        }
        if let category = currentCategory {
            await loadItems(for: category, force: true)
        }
    }

    func loadEpisodes(for series: SeriesItem) async {
        isLoadingEpisodes = true
        error = nil
        episodes = [:]
        do {
            episodes = try await api.getSeriesEpisodes(seriesId: series.seriesId)
            logger.info("Loaded \(self.episodes.count) seasons for '\(series.name)'")
        } catch {
            self.error = error.localizedDescription
        }
        isLoadingEpisodes = false
    }
}
