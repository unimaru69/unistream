import Foundation
import os

/// Manages VOD categories and movie lists.
@MainActor @Observable
final class VODViewModel {
    private let logger = Logger(subsystem: "fr.unimaru.unistream.tv", category: "VOD")

    private(set) var categories: [Category] = []
    private(set) var items: [VodItem] = []
    var isLoadingCategories = false
    var isLoadingItems = false
    var error: String?

    private let api: XtreamAPIService

    init(api: XtreamAPIService) {
        self.api = api
    }

    func loadCategories() async {
        isLoadingCategories = true
        error = nil
        do {
            categories = try await api.getVodCategories()
            logger.info("Loaded \(self.categories.count) VOD categories")
        } catch {
            self.error = error.localizedDescription
            logger.error("VOD categories failed: \(error.localizedDescription)")
        }
        isLoadingCategories = false
    }

    func loadItems(for category: Category) async {
        isLoadingItems = true
        error = nil
        items = []
        do {
            items = try await api.getVodStreams(categoryId: category.categoryId)
            logger.info("Loaded \(self.items.count) VOD items")
        } catch {
            self.error = error.localizedDescription
            logger.error("VOD items failed: \(error.localizedDescription)")
        }
        isLoadingItems = false
    }
}
