import UIKit
import CarPlay
import MediaPlayer

typealias CarPlayPlayableFetchCallback = (_ completionHandler: @escaping () -> Void ) -> Void
typealias CarPlayTabFetchCallback = (_ completionHandler: @escaping ([CarPlayPlayableItem]) -> Void ) -> Void

struct CarPlayPlayableItem {
    let element: PlayableContainable
    let image: UIImage?
    let fetchCB: CarPlayPlayableFetchCallback?

    func asContentItem() -> MPContentItem {
        let item = MPContentItem(identifier: element.name)
        item.title = element.name
        item.subtitle = element.subtitle
        item.isContainer = true
        item.isPlayable = true
        item.isStreamingContent = !element.playables.hasCachedItems
        if let image = image {
            item.artwork = MPMediaItemArtwork(boundsSize: image.size, requestHandler: { _ -> UIImage in
                return image
            })
        }
        return item
    }
    
    func fetch(completionHandler: @escaping () -> Void) {
        if let fetchCB = fetchCB {
            fetchCB(completionHandler)
        } else {
            completionHandler()
        }
    }
}

struct CarPlayContainerItem {
    let element: PlayableContainable
    let image: UIImage?
    var containerItems = [CarPlayContainerItem]()
    var playableItems = [CarPlayPlayableItem]()

    var itemsCount: Int {
        return containerItems.count + playableItems.count
    }
    var items: [MPContentItem] {
        var result = [MPContentItem]()
        result.append(contentsOf: containerItems.compactMap{ $0.asContentItem() })
        result.append(contentsOf: playableItems.compactMap{ $0.asContentItem() })
        return result
    }
    
    func asContentItem() -> MPContentItem {
        let item = MPContentItem(identifier: element.name)
        item.title = element.name
        item.subtitle = element.subtitle
        item.isContainer = true
        item.isPlayable = false
        if let image = image {
            item.artwork = MPMediaItemArtwork(boundsSize: image.size, requestHandler: { _ -> UIImage in
                return image
            })
        }
        return item
    }
}

class CarPlayTabData {
    let title: String
    let image: UIImage
    var containerItems = [CarPlayContainerItem]()
    var playableItems = [CarPlayPlayableItem]()
    var fetchCB: CarPlayTabFetchCallback?
    
    init(title: String, image: UIImage, fetchCB: CarPlayTabFetchCallback?) {
        self.title = title
        self.image = image
        self.fetchCB = fetchCB
    }
    
    var itemsCount: Int {
        return containerItems.count + playableItems.count
    }
    var items: [MPContentItem] {
        var result = [MPContentItem]()
        result.append(contentsOf: containerItems.compactMap{ $0.asContentItem() })
        result.append(contentsOf: playableItems.compactMap{ $0.asContentItem() })
        return result
    }

    func asContentItem() -> MPContentItem {
        let item = MPContentItem(identifier: title)
        item.title = title
        item.isContainer = true
        item.isPlayable = false
        item.artwork = MPMediaItemArtwork(boundsSize: image.size, requestHandler: { _ -> UIImage in
            return self.image
        })
        return item
    }
    
    func fetch(completionHandler: @escaping () -> Void) {
        if let fetchCB = fetchCB {
            fetchCB() { items in
                self.playableItems = items
                completionHandler()
            }
        } else {
            completionHandler()
        }
    }
}

class CarPlayHandler: NSObject {

    let persistentStorage: PersistentStorage
    let library: LibraryStorage
    let backendApi: BackendApi
    let player: PlayerFacade
    var playableContentManager: MPPlayableContentManager
    var tabData = [CarPlayTabData]()

    init(persistentStorage: PersistentStorage, library: LibraryStorage, backendApi: BackendApi, player: PlayerFacade, playableContentManager: MPPlayableContentManager) {
        self.persistentStorage = persistentStorage
        self.library = library
        self.backendApi = backendApi
        self.player = player
        self.playableContentManager = playableContentManager
    }
    
    func initialize() {
        playableContentManager.delegate = self
        playableContentManager.dataSource = self
        populate()
    }
    
    func populate() {
        let artworkDisplayStyle = persistentStorage.settings.artworkDisplayPreference
        let playlistsData = CarPlayTabData(title: "Playlists", image: UIImage.playlistCarplay, fetchCB: nil)
        playlistsData.fetchCB = { completionHandler in
            self.persistentStorage.context.performAndWait {
                let playlists = self.library.getPlaylistsForCarPlay(sortType: self.persistentStorage.settings.playlistsSortSetting)
                var playlistItems = [CarPlayPlayableItem]()
                for playlist in playlists {
                    let item = CarPlayPlayableItem(element: playlist, image: nil, fetchCB: nil)
                    playlistItems.append(item)
                }
                completionHandler(playlistItems)
            }
        }

        let recentAlbumsData = CarPlayTabData(title: "Recent Albums", image: UIImage.albumCarplay, fetchCB: nil)
        recentAlbumsData.fetchCB = { completionHandler in
            self.persistentStorage.context.performAndWait {
                let albums = self.library.getRecentAlbumsForCarPlay()
                var albumItems = [CarPlayPlayableItem]()
                for album in albums {
                    let item = CarPlayPlayableItem(element: album, image: album.image(setting: artworkDisplayStyle), fetchCB: nil)
                    albumItems.append(item)
                }
                completionHandler(albumItems)
            }
        }

        let recentSongsData = CarPlayTabData(title: "Recent Songs", image: UIImage.musicalNotesCarplay, fetchCB: nil)
        recentSongsData.fetchCB = { completionHandler in
            self.persistentStorage.context.performAndWait {
                let songs = self.library.getRecentSongsForCarPlay()
                var songItems = [CarPlayPlayableItem]()
                for song in songs {
                    let item = CarPlayPlayableItem(element: song, image: song.image(setting: artworkDisplayStyle), fetchCB: nil)
                    songItems.append(item)
                }
                completionHandler(songItems)
            }
        }

        let podcastsData = CarPlayTabData(title: "Podcasts", image: UIImage.podcastCarplay, fetchCB: nil)
        podcastsData.fetchCB = { completionHandler in
            self.persistentStorage.context.performAndWait {
                let podcasts = self.library.getPodcastsForCarPlay()
                var podcastItems = [CarPlayPlayableItem]()
                for podcast in podcasts {
                    let item = CarPlayPlayableItem(element: podcast, image: podcast.image(setting: artworkDisplayStyle), fetchCB: nil)
                    podcastItems.append(item)
                }
                completionHandler(podcastItems)
            }
        }

        tabData = [playlistsData, recentAlbumsData, recentSongsData, podcastsData]
    }
}

extension CarPlayHandler: MPPlayableContentDelegate {
    func playableContentManager(_ contentManager: MPPlayableContentManager, initiatePlaybackOfContentItemAt indexPath: IndexPath, completionHandler: @escaping (Error?) -> Void) {
        DispatchQueue.main.async {
            guard indexPath.count > 0 else {
                completionHandler(nil)
                return
            }
            var containable: PlayableContainable? = nil
            if indexPath.count == 2 {
                let tabIndex = indexPath[0]
                let secondIndex = indexPath[1]
                containable = self.tabData[tabIndex].playableItems[secondIndex].element
            } else if indexPath.count == 3 {
                let tabIndex = indexPath[0]
                let secondIndex = indexPath[1]
                let thirdIndex = indexPath[2]
                containable = self.tabData[tabIndex].containerItems[secondIndex].playableItems[thirdIndex].element
            }

            if let containable = containable {
                let playContext = PlayContext(containable: containable, playables: containable.playables.filterCached())
                self.player.play(context: playContext)
            }
            completionHandler(nil)
            
            #if targetEnvironment(simulator)
                // Workaround to make the Now Playing working on the simulator:
                // Source: https://stackoverflow.com/questions/52818170/handling-playback-events-in-carplay-with-mpnowplayinginfocenter
                UIApplication.shared.endReceivingRemoteControlEvents()
                UIApplication.shared.beginReceivingRemoteControlEvents()
            #endif
        }
    }
    
    func beginLoadingChildItems(at indexPath: IndexPath, completionHandler: @escaping (Error?) -> Void) {
        if indexPath.count == 1 {
            // Tab section
            let tabIndex = indexPath[0]
            tabData[tabIndex].fetch {
                completionHandler(nil)
            }
        } else if indexPath.count == 2 {
            let tabIndex = indexPath[0]
            let secondIndex = indexPath[1]
            if !tabData[tabIndex].containerItems.isEmpty {
                completionHandler(nil)
            } else {
                tabData[tabIndex].playableItems[secondIndex].fetch {
                    completionHandler(nil)
                }
            }
        } else if indexPath.count == 3 {
            let tabIndex = indexPath[0]
            let secondIndex = indexPath[1]
            let thirdIndex = indexPath[2]
            if !tabData[tabIndex].containerItems[secondIndex].containerItems.isEmpty {
                completionHandler(nil)
            } else {
                tabData[tabIndex].containerItems[secondIndex].playableItems[thirdIndex].fetch {
                    completionHandler(nil)
                }
            }
        } else {
            completionHandler(nil)
        }
    }
}

extension CarPlayHandler: MPPlayableContentDataSource {
    func numberOfChildItems(at indexPath: IndexPath) -> Int {
        if indexPath.indices.isEmpty {
            // Number of tabs
            return tabData.count
        } else if indexPath.indices.count == 1 {
            let tabIndex = indexPath[0]
            return tabData[tabIndex].itemsCount
        } else if indexPath.indices.count == 2 {
            let tabIndex = indexPath[0]
            let secondIndex = indexPath[1]
            return tabData[tabIndex].containerItems[secondIndex].itemsCount
        } else if indexPath.indices.count == 3 {
            let tabIndex = indexPath[0]
            let secondIndex = indexPath[1]
            let thirdIndex = indexPath[2]
            return tabData[tabIndex].containerItems[secondIndex].containerItems[thirdIndex].itemsCount
        }
        return 0
    }
    
    func contentItem(at indexPath: IndexPath) -> MPContentItem? {
        if indexPath.count == 1 {
            // Tab section
            let tabIndex = indexPath[0]
            return tabData[tabIndex].asContentItem()
        } else if indexPath.count == 2 {
            let tabIndex = indexPath[0]
            let secondIndex = indexPath[1]
            return tabData[tabIndex].items[secondIndex]
        } else if indexPath.count == 3 {
            let tabIndex = indexPath[0]
            let secondIndex = indexPath[1]
            let thirdIndex = indexPath[2]
            return tabData[tabIndex].containerItems[secondIndex].items[thirdIndex]
        } else {
            return nil
        }
    }
}
