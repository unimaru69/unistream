import SwiftUI

/// Design tokens for UniStream tvOS — spacing, radii, typography, colours.
/// See DESIGN.md at the repo root for the brand guidelines.
enum DS {

    // MARK: - Spacing

    /// Standard spacing scale — use instead of hardcoded values.
    enum Spacing {
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 40
    }

    /// Padding used on the outer edges of screens.
    enum Padding {
        /// Horizontal padding for the whole screen edges — 60pt on tvOS.
        static let screenHorizontal: CGFloat = 60
        /// Horizontal padding inside split-view detail panes — tighter.
        static let detailHorizontal: CGFloat = 40
        /// Top padding below the navigation title area.
        static let contentTop: CGFloat = 20
        /// Bottom padding at the end of a scrollable screen.
        static let contentBottom: CGFloat = 40
    }

    // MARK: - Corner radii

    enum Radius {
        /// Standard card corner radius (poster thumbnails, row backgrounds).
        static let card: CGFloat = 12
        /// Larger radius for hero / detail images.
        static let hero: CGFloat = 16
        /// Pill / chip radius — use Capsule() instead when possible.
        static let pill: CGFloat = 99
        /// Small radius for badges / tags.
        static let tag: CGFloat = 6
    }

    // MARK: - Focus

    enum Focus {
        /// Scale factor applied on focus for cards.
        static let cardScale: CGFloat = 1.08
        /// Scale factor for chips / sidebar rows (subtler).
        static let chipScale: CGFloat = 1.04
        /// Standard animation duration.
        static let animation: Animation = .easeOut(duration: 0.15)
    }

    // MARK: - Brand colours

    enum Colour {
        static let accent = Color(hex: 0x1B6B8A)
        static let accentLight = Color(hex: 0x2A8AB0)
        static let background = Color(hex: 0x0E0B1E)
        static let surface = Color(hex: 0x161230)
        static let logoBg = Color(hex: 0x161230)
        static let error = Color(hex: 0xC62828)
        static let success = Color.green
    }
}
