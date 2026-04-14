import Foundation

/// Content category — mirrors Flutter's `Category`.
struct Category: Identifiable, Hashable {
    let categoryId: String
    var categoryName: String
    var parentId: Int

    var id: String { categoryId }

    init(categoryId: String, categoryName: String = "", parentId: Int = 0) {
        self.categoryId = categoryId
        self.categoryName = categoryName
        self.parentId = parentId
    }

    /// Parse from JSON dict — tolerant of int/string mixing.
    init(json: [String: Any]) {
        categoryId = "\(json["category_id"] ?? "")"
        categoryName = json["category_name"] as? String ?? ""
        if let p = json["parent_id"] as? Int {
            parentId = p
        } else if let s = json["parent_id"] as? String {
            parentId = Int(s) ?? 0
        } else {
            parentId = 0
        }
    }
}
