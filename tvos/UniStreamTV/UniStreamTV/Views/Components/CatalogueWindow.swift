import Foundation

/// A sliding window over a catalogue grid, grown by focus rather than by
/// scroll offset.
///
/// tvOS has no touch scrolling: the user moves *focus* and the scroll view
/// follows it. So "load more as you near the bottom" has to mean "load more
/// when focus nears the last card", not a `contentOffset` threshold.
///
/// What this exists to bound is the focus map. UIKit builds a focus region
/// per card and, on every focus move, evaluates occlusions across all of
/// them against whatever is drawn on top — the preview overlay each grid
/// keeps at its bottom edge. That evaluation is quadratic in the number of
/// regions, and an Xtream category runs to thousands of entries. Sentry
/// caught the result as 2 s+ App Hangs inside `_UIFocusRegionEvaluator`
/// (UNISTREAM-31 / 3D), worst on the A8 Apple TV HD. `LazyVGrid` does not
/// bound it on its own: it realises well beyond the viewport and holds on
/// to what it has realised, so the region count only ever grows.
struct CatalogueWindow {
    /// Cards rendered initially, and how many each extension adds. About
    /// twenty rows of a six-wide adaptive grid — several screens of
    /// travel before the first extension, so the common case of browsing
    /// the top of a category never pages at all.
    static let pageSize = 120

    /// How close to the end of the window focus must land before the next
    /// page is appended. A row or two of lead time, so the cards are in
    /// place before the user's focus arrives at them.
    static let extendThreshold = 24

    private(set) var limit = pageSize

    /// Back to a single page. Call whenever the underlying list changes
    /// identity — category switch, search, sort — so the window doesn't
    /// stay wide open over a list the user has since narrowed.
    mutating func reset() {
        limit = Self.pageSize
    }

    /// The prefix of `items` that should actually be rendered.
    func applied<T>(to items: [T]) -> [T] {
        items.count > limit ? Array(items.prefix(limit)) : items
    }

    /// Grow the window when `focusedId` is one of the last
    /// ``extendThreshold`` cards currently rendered.
    ///
    /// Only the tail of the window is searched, which keeps this O(page
    /// threshold) on every focus move rather than O(catalogue) — the
    /// difference between 24 and several thousand string comparisons each
    /// time the user nudges the remote.
    mutating func extendIfNeeded<T>(
        focusedId: String,
        in items: [T],
        identifiedBy id: (T) -> String
    ) {
        guard limit < items.count else { return }
        let tailStart = max(0, limit - Self.extendThreshold)
        let tail = items[tailStart..<min(limit, items.count)]
        guard tail.contains(where: { id($0) == focusedId }) else { return }
        limit = min(limit + Self.pageSize, items.count)
    }
}
