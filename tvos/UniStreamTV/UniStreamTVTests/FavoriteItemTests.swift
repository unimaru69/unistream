import Testing
import Foundation
@testable import UniStreamTV

@Suite("FavoriteItem")
struct FavoriteItemTests {

    // MARK: - Factory: Channel

    @Test func fromChannelSetsLiveMode() {
        let channel = Channel(json: [
            "stream_id": 42,
            "name": "France 2",
            "num": 2,
            "cover": "https://img/f2.png",
            "stream_icon": "https://icon/f2.png",
            "category_id": "cat_1",
        ])
        let fav = FavoriteItem.from(channel: channel)
        #expect(fav.key == "42")
        #expect(fav.name == "France 2")
        #expect(fav.mode == "live")
        #expect(fav.streamId == "42")
        #expect(fav.cover == "https://img/f2.png")
        #expect(fav.seriesId == nil)
    }

    // MARK: - Factory: VOD

    @Test func fromVodSetsMovieMode() {
        let vod = VodItem(json: [
            "stream_id": 100,
            "name": "Inception",
            "cover": "https://img/inception.jpg",
            "category_id": "movies_1",
            "container_extension": "mkv",
            "rating": "8.8",
        ])
        let fav = FavoriteItem.from(vod: vod)
        #expect(fav.key == "100")
        #expect(fav.mode == "movie")
        #expect(fav.containerExtension == "mkv")
        #expect(fav.rating == "8.8")
    }

    // MARK: - Factory: Series

    @Test func fromSeriesSetsSeriesMode() {
        let series = SeriesItem(json: [
            "series_id": 200,
            "name": "Breaking Bad",
            "cover": "https://img/bb.jpg",
            "category_id": "series_1",
            "rating": "9.5",
        ])
        let fav = FavoriteItem.from(series: series)
        #expect(fav.key == "200")
        #expect(fav.name == "Breaking Bad")
        #expect(fav.mode == "series")
        #expect(fav.seriesId == "200")
        #expect(fav.streamId == nil)
    }

    // MARK: - Display Icon

    @Test func displayIconPrefersCover() {
        let fav = FavoriteItem(key: "1", name: "T", cover: "cover.png", mode: "live", streamIcon: "icon.png")
        #expect(fav.displayIcon == "cover.png")
    }

    @Test func displayIconFallsBackToStreamIcon() {
        let fav = FavoriteItem(key: "1", name: "T", cover: nil, mode: "live", streamIcon: "icon.png")
        #expect(fav.displayIcon == "icon.png")
    }

    @Test func displayIconEmptyWhenBothNil() {
        let fav = FavoriteItem(key: "1", name: "T", mode: "live")
        #expect(fav.displayIcon == "")
    }
}
