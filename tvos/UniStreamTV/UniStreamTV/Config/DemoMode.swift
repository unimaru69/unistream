import Foundation

/// Demo mode flag — enables fake data for App Store screenshots.
/// Activate by passing `--demo` as a launch argument (simctl or Xcode scheme).
enum DemoMode {
    #if DEBUG
    static let isActive = ProcessInfo.processInfo.arguments.contains("--demo")
    #else
    static let isActive = false
    #endif
}

/// Fictional data used in demo mode for screenshots.
/// Channel/movie/series names are generic and do NOT reference real brands.
enum DemoData {

    // MARK: - Live Categories

    static let liveCategories: [Category] = [
        Category(categoryId: "l1", categoryName: "Actualités"),
        Category(categoryId: "l2", categoryName: "Sport"),
        Category(categoryId: "l3", categoryName: "Documentaire"),
        Category(categoryId: "l4", categoryName: "Jeunesse"),
        Category(categoryId: "l5", categoryName: "Musique"),
        Category(categoryId: "l6", categoryName: "Culture"),
        Category(categoryId: "l7", categoryName: "Lifestyle"),
    ]

    // MARK: - Live Channels

    static let liveChannels: [Channel] = [
        chan("1", "News Channel HD", "l1"),
        chan("2", "Info 24", "l1"),
        chan("3", "World News Live", "l1"),
        chan("4", "Business Today", "l1"),
        chan("5", "Sports HD", "l2"),
        chan("6", "Sport Action", "l2"),
        chan("7", "Football Live", "l2"),
        chan("8", "Tennis+", "l2"),
        chan("9", "Discovery World", "l3"),
        chan("10", "Nature TV", "l3"),
        chan("11", "Science Channel", "l3"),
        chan("12", "History Plus", "l3"),
        chan("13", "Kids Cartoons", "l4"),
        chan("14", "Junior TV", "l4"),
        chan("15", "Music Box", "l5"),
        chan("16", "Top Hits Live", "l5"),
        chan("17", "Arts & Culture", "l6"),
        chan("18", "Travel HD", "l7"),
        chan("19", "Cooking Channel", "l7"),
        chan("20", "Home & Garden", "l7"),
    ]

    private static func chan(_ id: String, _ name: String, _ catId: String) -> Channel {
        Channel(json: [
            "stream_id": id,
            "name": name,
            "category_id": catId,
            "num": Int(id) ?? 0,
            "tv_archive": "1",
            "tv_archive_duration": "7",
            "stream_icon": iconUrl(name),
        ])
    }

    // MARK: - VOD Categories

    static let vodCategories: [Category] = [
        Category(categoryId: "v1", categoryName: "Action"),
        Category(categoryId: "v2", categoryName: "Drame"),
        Category(categoryId: "v3", categoryName: "Comédie"),
        Category(categoryId: "v4", categoryName: "Aventure"),
    ]

    // MARK: - VOD Items

    static let vodItems: [VodItem] = [
        vod("101", "Midnight Coder", "v1", "7.8"),
        vod("102", "Urban Legends", "v1", "7.1"),
        vod("103", "Neon Streets", "v1", "7.7"),
        vod("104", "Shadow Hunters", "v1", "8.0"),
        vod("105", "Steel Horizon", "v1", "7.6"),
        vod("106", "Last Protocol", "v1", "7.9"),
        vod("107", "City Lights", "v2", "8.2"),
        vod("108", "The Last Summer", "v2", "8.0"),
        vod("109", "Silent River", "v2", "7.3"),
        vod("110", "The Comedian", "v3", "7.4"),
        vod("111", "Old Friends", "v3", "7.0"),
        vod("112", "Mountain Trail", "v4", "7.5"),
        vod("113", "Desert Wind", "v4", "6.9"),
        vod("114", "Northern Star", "v4", "8.1"),
    ]

    private static func vod(_ id: String, _ name: String, _ catId: String, _ rating: String) -> VodItem {
        VodItem(json: [
            "stream_id": id,
            "name": name,
            "category_id": catId,
            "container_extension": "mp4",
            "rating": rating,
            "cover": posterUrl(name, id: id),
        ])
    }

    // MARK: - Series Categories

    static let seriesCategories: [Category] = [
        Category(categoryId: "s1", categoryName: "Thriller"),
        Category(categoryId: "s2", categoryName: "Drame"),
        Category(categoryId: "s3", categoryName: "Science-fiction"),
        Category(categoryId: "s4", categoryName: "Comédie"),
    ]

    // MARK: - Series

    static let seriesList: [SeriesItem] = [
        series("201", "The Archive", "s1", "8.5", "3"),
        series("202", "Crossroads", "s1", "8.0", "4"),
        series("203", "Cold Trail", "s1", "8.1", "2"),
        series("204", "Night Watchman", "s1", "8.2", "3"),
        series("205", "Hidden Truths", "s1", "7.9", "2"),
        series("206", "Sunrise Valley", "s2", "7.8", "2"),
        series("207", "Family Ties", "s2", "7.4", "5"),
        series("208", "Beyond Tomorrow", "s3", "8.7", "2"),
        series("209", "Station Zero", "s3", "8.3", "3"),
        series("210", "The Neighbors", "s4", "7.2", "6"),
    ]

    private static func series(_ id: String, _ name: String, _ catId: String, _ rating: String, _ seasons: String) -> SeriesItem {
        SeriesItem(json: [
            "series_id": id,
            "name": name,
            "category_id": catId,
            "rating": rating,
            "num_seasons": seasons,
            "cover": posterUrl(name, id: id),
        ])
    }

    // MARK: - EPG

    static func shortEpg(streamId: String, limit: Int = 10) -> [EpgProgram] {
        let now = Date()
        let titles = [
            "Journal du matin", "Grand reportage", "Le débat",
            "Direct international", "Magazine sportif",
            "Documentaire spécial", "Actualités",
            "Le journal du soir", "Analyse éco", "Rendez-vous culture",
        ]
        return (0..<limit).map { i in
            let start = now.addingTimeInterval(Double(30 * (i - 1)) * 60)
            let end = start.addingTimeInterval(30 * 60)
            return EpgProgram(json: [
                "title": titles[i % titles.count],
                "start_timestamp": Int(start.timeIntervalSince1970),
                "stop_timestamp": Int(end.timeIntervalSince1970),
                "start": "",
            ])
        }
    }

    // MARK: - Episodes

    static func episodes(forSeriesId id: String) -> [String: [Episode]] {
        var result: [String: [Episode]] = [:]
        for s in 1...3 {
            result["\(s)"] = (1...6).map { e in
                Episode(json: [
                    "id": "\(id)-s\(s)e\(e)",
                    "title": "Épisode \(e)",
                    "episode_num": "\(e)",
                    "container_extension": "mp4",
                ])
            }
        }
        return result
    }

    // MARK: - Placeholder URLs

    private static let palette = [
        "C62828", "2E7D32", "6A1B9A", "EF6C00", "AD1457",
        "00838F", "1565C0", "B71C1C", "283593", "F9A825",
        "4E342E", "1A237E", "4A148C", "006064", "E65100", "37474F",
    ]

    private static func colorFor(_ key: String) -> String {
        if let n = Int(key) { return palette[n % palette.count] }
        var hash: UInt32 = 0x811C9DC5
        for c in key.utf8 { hash ^= UInt32(c); hash &*= 0x01000193 }
        return palette[Int(hash) % palette.count]
    }

    static func posterUrl(_ name: String, id: String? = nil) -> String {
        let color = colorFor(id ?? name)
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        return "https://placehold.co/400x600/\(color)/FFFFFF/png?text=\(encoded)"
    }

    static func iconUrl(_ name: String) -> String {
        let letter = String(name.prefix(1)).uppercased()
        let color = colorFor(name)
        return "https://placehold.co/300x300/\(color)/FFFFFF/png?text=\(letter)"
    }
}
