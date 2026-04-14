import Foundation

/// Content type discriminator — mirrors Flutter's `ContentMode`.
enum ContentMode: String, Codable, CaseIterable, Identifiable {
    case live
    case vod
    case series

    var id: String { rawValue }

    var label: String {
        switch self {
        case .live: "Live"
        case .vod: "VOD"
        case .series: "Séries"
        }
    }
}
