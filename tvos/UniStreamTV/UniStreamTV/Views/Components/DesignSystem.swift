import SwiftUI

/// Design tokens for UniStream tvOS — version 2 (Strimr / Apple TV+ inspired).
///
/// Every spacing / radius / type / colour value used across the app should
/// flow from this enum. Hard-coded magic numbers in views are a smell — if
/// you find one, lift it here and reference back.
///
/// Companion: `lib/core/colors.dart` for the Flutter side; the two should
/// stay in lock-step. See `DESIGN.md` at the repo root for the rationale
/// behind each token (typography scale, motion durations, focus
/// treatment).
enum DS {

    // MARK: - Spacing

    /// 4-pt grid. Use `DS.Spacing.md` etc. instead of hard-coded literals.
    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        static let xxxl: CGFloat = 64
        static let huge: CGFloat = 96
    }

    /// Screen-edge paddings — tvOS safe area is ~60pt by default.
    enum Padding {
        static let screenHorizontal: CGFloat = 60
        /// Horizontal padding inside split-view detail panes — tighter.
        static let detailHorizontal: CGFloat = 40
        static let contentTop: CGFloat = 20
        static let contentBottom: CGFloat = 60
        /// Vertical breathing room between major sections.
        static let sectionGap: CGFloat = 48
    }

    // MARK: - Corner radii

    enum Radius {
        /// Standard poster / row card.
        static let card: CGFloat = 12
        /// Larger radius for hero / detail / modal.
        static let hero: CGFloat = 20
        /// Pill / chip radius — prefer `Capsule()` when possible.
        static let pill: CGFloat = 99
        /// Small radius for badges / tags / metadata pills.
        static let tag: CGFloat = 6
    }

    // MARK: - Focus

    /// Apple-style focus treatment: subtle scale + soft shadow + thin
    /// accent ring. Read by `FocusableCard` / `tvCard` button styles.
    enum Focus {
        /// Card scale on focus — tighter than the previous 1.08 so the
        /// grid doesn't feel jumpy when navigating between cards.
        static let cardScale: CGFloat = 1.10
        /// Sidebar rows / chips — subtler.
        static let chipScale: CGFloat = 1.04
        /// Shadow drop on focused cards.
        static let shadowRadius: CGFloat = 24
        static let shadowY: CGFloat = 8
        static let shadowOpacity: Double = 0.5
        /// Thin accent ring drawn on focused cards. Pulled from the
        /// brand teal at low opacity so it reads as a glow rather than
        /// a hard outline.
        static let ringWidth: CGFloat = 2
        /// Standard focus animation — long enough to feel intentional,
        /// short enough that grid scrolling never feels sluggish.
        static let animation: Animation = .easeOut(duration: 0.18)
    }

    // MARK: - Motion

    /// Standard durations — match Apple TV+'s "spring with subtle inertia"
    /// feel. Use these instead of hard-coding 0.3 everywhere.
    enum Motion {
        static let quick: Animation = .easeOut(duration: 0.15)
        static let standard: Animation = .easeOut(duration: 0.25)
        static let slow: Animation = .easeOut(duration: 0.40)
        /// Spring used for hero rotation / modal entry.
        static let spring: Animation = .spring(response: 0.45, dampingFraction: 0.85)
    }

    // MARK: - Brand colours

    /// Apple TV+ / Strimr-style palette: true black canvas, layered dark
    /// surfaces, single primary accent (brand teal). Avoid introducing
    /// per-screen one-off colours — extend this enum first.
    enum Colour {
        // Canvas
        /// True-black canvas — stronger than the previous 0x0E0B1E navy
        /// and matches Apple TV+ / Strimr / Plex first-party apps.
        static let background = Color(hex: 0x000000)
        /// Lifted surface (cards in dark mode, panels). +6% white.
        static let surface = Color(hex: 0x141414)
        /// Slightly lighter surface for nested elements (hover, focus
        /// preview backgrounds). +12% white.
        static let surfaceElevated = Color(hex: 0x1C1C1E)

        // Brand
        /// Primary brand teal — used for the focus ring, primary CTAs,
        /// the "À LA UNE" pill on the hero.
        static let accent = Color(hex: 0x1B6B8A)
        /// Hover / lighter variant of the accent.
        static let accentLight = Color(hex: 0x2A8AB0)
        /// Warm secondary used sparingly for "live now" / "new"
        /// highlights — keeps the UI from going monochrome.
        static let accentWarm = Color(hex: 0xFF6B5B)

        // Status
        static let error = Color(hex: 0xFF453A)
        static let success = Color(hex: 0x32D74B)
        static let warning = Color(hex: 0xFFD60A)

        // Text — derived from white at fixed opacities so they read
        // consistently against dark backgrounds. Pair with
        // `kCMTextMarkupAttribute_RelativeFontSize` on player items so
        // subtitles inherit a comparable rhythm.
        static let textPrimary = Color.white
        static let textSecondary = Color.white.opacity(0.72)
        static let textTertiary = Color.white.opacity(0.50)
        static let textDisabled = Color.white.opacity(0.30)

        // Brand legacy alias — keep until the few remaining call sites
        // are migrated.
        static let logoBg = Color(hex: 0x141414)
    }

    // MARK: - Typography
    //
    // Apple's recommendation for tvOS is SF Pro Display for headlines
    // and SF Pro Text for body — both shipped on the system, no asset
    // shipping needed. Use these helpers instead of `.font(.title)` so
    // tracking and weight stay coherent across the app.
    enum Typography {
        /// Hero title — used for the À LA UNE banner and similar
        /// statement headlines.
        static let displayHero: Font = .system(size: 56, weight: .bold, design: .default)
        /// Standard display title — large headers.
        static let display: Font = .system(size: 44, weight: .bold, design: .default)
        /// Section / page titles.
        static let title1: Font = .system(size: 32, weight: .bold, design: .default)
        /// Sub-section titles ("Continuer à regarder", "Catégories").
        static let title2: Font = .system(size: 24, weight: .semibold, design: .default)
        /// Card titles, dialog titles.
        static let title3: Font = .system(size: 20, weight: .semibold, design: .default)
        /// Body copy.
        static let body: Font = .system(size: 17, weight: .regular, design: .default)
        /// Slightly emphasised body — CTAs, focus titles.
        static let bodyEmphasised: Font = .system(size: 17, weight: .semibold, design: .default)
        /// Metadata, year + genre + duration pills.
        static let caption: Font = .system(size: 13, weight: .regular, design: .default)
        /// Labels (badges, "À LA UNE", "FILM", "VU").
        static let label: Font = .system(size: 13, weight: .semibold, design: .default)
            .smallCaps()
    }

    // MARK: - Materials

    /// Apple-style glass panels — wrap a view with `.background(DS.glass)`
    /// to get the system blur + slight tint of a light-on-dark Apple TV
    /// modal panel.
    static let glass: Material = .ultraThinMaterial
    static let glassRegular: Material = .regularMaterial
}

// MARK: - Convenience modifiers

extension View {
    /// Apply the standard focus card treatment — scale + shadow + accent
    /// ring on focus. Use on top of a Button label or inside a
    /// custom focusable card.
    func focusCardEffect(isFocused: Bool, cornerRadius: CGFloat = DS.Radius.card) -> some View {
        self
            .scaleEffect(isFocused ? DS.Focus.cardScale : 1.0)
            .shadow(
                color: .black.opacity(isFocused ? DS.Focus.shadowOpacity : 0),
                radius: DS.Focus.shadowRadius,
                y: DS.Focus.shadowY
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        DS.Colour.accent.opacity(isFocused ? 0.7 : 0),
                        lineWidth: DS.Focus.ringWidth
                    )
            )
            .animation(DS.Focus.animation, value: isFocused)
    }
}
