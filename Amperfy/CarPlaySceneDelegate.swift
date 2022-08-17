import Foundation
import UIKit
import CarPlay
import AmperfyKit

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    
    static let maxTreeDepth = 4
    
    lazy var appDelegate = {
        return UIApplication.shared.delegate as! AppDelegate
    }()
    var isOfflineMode: Bool {
        return appDelegate.persistentStorage.settings.isOfflineMode
    }
    var artworkDisplayPreference: ArtworkDisplayPreference {
        return self.appDelegate.persistentStorage.settings.artworkDisplayPreference
    }
    
    var interfaceController: CPInterfaceController?
    
    /// CarPlay connected
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didConnect interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        
        configureNowPlayingTemplate()

        let tab = CPTabBarTemplate(templates: [
            createLibraryTab(),
            createPlaylistsTab(),
            createPodcastsTab()
        ])
        self.interfaceController?.setRootTemplate(tab, animated: true, completion: nil)
    }
    
    /// CarPlay disconnected
    private func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didDisconnect interfaceController: CPInterfaceController) {
        self.interfaceController = nil
    }
    
    private func configureNowPlayingTemplate() {
        CPNowPlayingTemplate.shared.updateNowPlayingButtons([
            CPNowPlayingRepeatButton(handler: { [weak self] button in
                guard let `self` = self else { return }
                self.appDelegate.player.setRepeatMode(self.appDelegate.player.repeatMode.nextMode)
            }),
            CPNowPlayingShuffleButton(handler: { [weak self] button in
                guard let `self` = self else { return }
                self.appDelegate.player.toggleShuffle()
            })
        ])
    }
    
    private func createLibraryTab() -> CPListTemplate {
        let playlistSection = CPListItem(text: "Playlists", detailText: nil, image: nil, accessoryImage: nil, accessoryType: .disclosureIndicator)
        playlistSection.handler = { [weak self] item, completion in
            guard let `self` = self else { completion(); return }
            let sections = self.createPlaylistsSections(treeDepth: 1)
            let playlistTemplate = CPListTemplate(title: "Playlists", sections: [
                CPListSection(items: sections)
            ])
            self.interfaceController?.pushTemplate(playlistTemplate, animated: true, completion: nil)
            completion()
        }
        
        let artistsSection = CPListItem(text: "Artists", detailText: nil, image: nil, accessoryImage: nil, accessoryType: .disclosureIndicator)
        artistsSection.handler = { [weak self] item, completion in
            guard let `self` = self else { completion(); return }
            let sections = self.createArtistsSections(treeDepth: 1)
            let playlistTemplate = CPListTemplate(title: "Artists", sections: [
                CPListSection(items: sections)
            ])
            self.interfaceController?.pushTemplate(playlistTemplate, animated: true, completion: nil)
            completion()
        }
        
        let albumsSection = CPListItem(text: "Albums", detailText: nil, image: nil, accessoryImage: nil, accessoryType: .disclosureIndicator)
        albumsSection.handler = { [weak self] item, completion in
            guard let `self` = self else { completion(); return }
            let sections = self.createAlbumsSections(treeDepth: 1)
            let playlistTemplate = CPListTemplate(title: "Albums", sections: [
                CPListSection(items: sections)
            ])
            self.interfaceController?.pushTemplate(playlistTemplate, animated: true, completion: nil)
            completion()
        }
        
        let songsSection = CPListItem(text: "Songs", detailText: nil, image: nil, accessoryImage: nil, accessoryType: .disclosureIndicator)
        songsSection.handler = { [weak self] item, completion in
            guard let `self` = self else { completion(); return }
            let sections = self.createSongsSections(treeDepth: 1)
            let playlistTemplate = CPListTemplate(title: "Songs", sections: [
                CPListSection(items: sections)
            ])
            self.interfaceController?.pushTemplate(playlistTemplate, animated: true, completion: nil)
            completion()
        }
        
        let podcastSection = CPListItem(text: "Podcasts", detailText: nil, image: nil, accessoryImage: nil, accessoryType: .disclosureIndicator)
        podcastSection.handler = { [weak self] item, completion in
            guard let `self` = self else { completion(); return }
            let sections = self.createPodcastsSections(treeDepth: 1)
            let playlistTemplate = CPListTemplate(title: "Podcasts", sections: [
                CPListSection(items: sections)
            ])
            self.interfaceController?.pushTemplate(playlistTemplate, animated: true, completion: nil)
            completion()
        }
        
        let libraryTab = CPListTemplate(title: "Library", sections: [CPListSection(items: [
            playlistSection,
            artistsSection,
            albumsSection,
            songsSection,
            podcastSection
        ])])
        libraryTab.tabImage = UIImage.musicLibrary
        return libraryTab
    }
    
    private func createPlaylistsTab() -> CPListTemplate {
        let sections = createPlaylistsSections(treeDepth: 1)
        let playlistTab = CPListTemplate(title: "Playlists", sections: [CPListSection(items: sections)])
        playlistTab.tabImage = UIImage.playlist
        return playlistTab
    }
    
    private func createPodcastsTab() -> CPListTemplate {
        let sections = createPodcastsSections(treeDepth: 1)
        let podcastsTab = CPListTemplate(title: "Podcasts", sections: [CPListSection(items: sections)])
        podcastsTab.tabImage = UIImage.podcast
        return podcastsTab
    }

    private func createArtistsSections(treeDepth: Int) -> [CPListTemplateItem] {
        let favoritesSection = CPListItem(text: "Favorites", detailText: nil, image: UIImage.createArtwork(with: UIImage.heartFill, iconSizeType: .small, switchColors: true), accessoryImage: nil, accessoryType: .disclosureIndicator)
        favoritesSection.handler = { [weak self] item, completion in
            guard let `self` = self else { completion(); return }
            var favoriteSections = [CPListTemplateItem]()
            let artists = self.appDelegate.library.getFavoriteArtistsForCarPlay(onlyCached: self.isOfflineMode)
            for artist in artists {
                let section = self.createDetailTemplate(for: artist, treeDepth: treeDepth+1)
                favoriteSections.append(section)
            }
            let favoriteTemplate = CPListTemplate(title: "Favorites", sections: [
                CPListSection(items: favoriteSections)
            ])
            self.interfaceController?.pushTemplate(favoriteTemplate, animated: true, completion: nil)
            completion()
        }
        return [favoritesSection]
    }
    
    private func createAlbumsSections(treeDepth: Int) -> [CPListTemplateItem] {
        let favoritesSection = CPListItem(text: "Favorites", detailText: nil, image: UIImage.createArtwork(with: UIImage.heartFill, iconSizeType: .small, switchColors: true), accessoryImage: nil, accessoryType: .disclosureIndicator)
        favoritesSection.handler = { [weak self] item, completion in
            guard let `self` = self else { completion(); return }
            var favoriteSections = [CPListTemplateItem]()
            let albums = self.appDelegate.library.getFavoriteAlbumsForCarPlay(onlyCached: self.isOfflineMode)
            for album in albums {
                let section = self.createDetailTemplate(for: album, treeDepth: treeDepth+1)
                favoriteSections.append(section)
            }
            let favoriteTemplate = CPListTemplate(title: "Favorites", sections: [
                CPListSection(items: favoriteSections)
            ])
            self.interfaceController?.pushTemplate(favoriteTemplate, animated: true, completion: nil)
            completion()
        }
        
        let recentlyAddedSection = CPListItem(text: "Recently added", detailText: nil, image: UIImage.createArtwork(with: UIImage.clock, iconSizeType: .small, switchColors: true), accessoryImage: nil, accessoryType: .disclosureIndicator)
        recentlyAddedSection.handler = { [weak self] item, completion in
            guard let `self` = self else { completion(); return }
            var recentlyAddedSections = [CPListTemplateItem]()
            let albums = self.appDelegate.library.getRecentAlbumsForCarPlay(onlyCached: self.isOfflineMode)
            for album in albums {
                let section = self.createDetailTemplate(for: album, treeDepth: treeDepth+1)
                recentlyAddedSections.append(section)
            }
            let favoriteTemplate = CPListTemplate(title: "Recently added", sections: [
                CPListSection(items: recentlyAddedSections)
            ])
            self.interfaceController?.pushTemplate(favoriteTemplate, animated: true, completion: nil)
            completion()
        }
        return [favoritesSection, recentlyAddedSection]
    }
    
    private func createSongsSections(treeDepth: Int) -> [CPListTemplateItem] {
        let favoritesSection = CPListItem(text: "Favorites", detailText: nil, image: UIImage.createArtwork(with: UIImage.heartFill, iconSizeType: .small, switchColors: true), accessoryImage: nil, accessoryType: .disclosureIndicator)
        favoritesSection.handler = { [weak self] item, completion in
            guard let `self` = self else { completion(); return }
            var favoriteSections = [CPListTemplateItem]()
            let songs = self.appDelegate.library.getFavoriteSongsForCarPlay(onlyCached: self.isOfflineMode)
            favoriteSections.append(self.createPlayShuffledListItem(playContext: PlayContext(name: "All favorite songs", playables: songs), treeDepth: treeDepth+1))
            for (index, song) in songs.enumerated() {
                let section = self.createDetailTemplate(for: song, playContext: PlayContext(name: "All favorite songs", index: index, playables: songs), treeDepth: treeDepth+1)
                favoriteSections.append(section)
            }
            let favoriteTemplate = CPListTemplate(title: "Favorites", sections: [
                CPListSection(items: favoriteSections)
            ])
            self.interfaceController?.pushTemplate(favoriteTemplate, animated: true, completion: nil)
            completion()
        }
        
        let recentlyAddedSection = CPListItem(text: "Recently added", detailText: nil, image: UIImage.createArtwork(with: UIImage.clock, iconSizeType: .small, switchColors: true), accessoryImage: nil, accessoryType: .disclosureIndicator)
        recentlyAddedSection.handler = { [weak self] item, completion in
            guard let `self` = self else { completion(); return }
            var recentlyAddedSections = [CPListTemplateItem]()
            let songs = self.appDelegate.library.getRecentSongsForCarPlay(onlyCached: self.isOfflineMode)
            recentlyAddedSections.append(self.createPlayShuffledListItem(playContext: PlayContext(name: "All recent songs", playables: songs), treeDepth: treeDepth+1))
            for (index, song) in songs.enumerated() {
                let section = self.createDetailTemplate(for: song, playContext: PlayContext(name: "All recent songs", index: index, playables: songs), treeDepth: treeDepth+1)
                recentlyAddedSections.append(section)
            }
            let favoriteTemplate = CPListTemplate(title: "Recently added", sections: [
                CPListSection(items: recentlyAddedSections)
            ])
            self.interfaceController?.pushTemplate(favoriteTemplate, animated: true, completion: nil)
            completion()
        }
        
        let songs = self.appDelegate.library.getSongs().filterCached(dependigOn: self.appDelegate.persistentStorage.settings.isOfflineMode)
        let playRandomSongsSection = self.createPlayShuffledListItem(playContext: PlayContext(name: "Song Collection", playables: songs[randomPick: LibraryStorage.carPlayMaxElements]), treeDepth: treeDepth+1, text: "Play random songs")
        
        return [favoritesSection, recentlyAddedSection, playRandomSongsSection]
    }
    
    private func createDetailTemplate(for artist: Artist, treeDepth: Int) -> CPListItem {
        let section = CPListItem(text: artist.name, detailText: artist.subtitle, image: artist.image(setting: artworkDisplayPreference), accessoryImage: nil, accessoryType: .disclosureIndicator)
        section.handler = { [weak self] item, completion in
            guard let `self` = self else { completion(); return }
            var albumItems = [CPListItem]()
            albumItems.append(self.createPlayShuffledListItem(playContext: PlayContext(containable: artist, playables: artist.playables.filterCached(dependigOn: self.isOfflineMode)), treeDepth: treeDepth+1))
            albumItems.append(self.createDetailAllSongsTemplate(for: artist, treeDepth: treeDepth+1))
            let artistAlbums = self.appDelegate.library.getAlbums(whichContainsSongsWithArtist: artist, onlyCached: self.isOfflineMode).prefix(LibraryStorage.carPlayMaxElements)
            for album in artistAlbums {
                let listItem = self.createDetailTemplate(for: album, treeDepth: treeDepth+1)
                albumItems.append(listItem)
            }
            let artistTemplate = CPListTemplate(title: artist.name, sections: [
                CPListSection(items: albumItems)
            ])
            self.interfaceController?.pushTemplate(artistTemplate, animated: true, completion: nil)
            completion()
        }
        return section
    }
    
    private func createDetailAllSongsTemplate(for artist: Artist, treeDepth: Int) -> CPListItem {
        let section = CPListItem(text: "All songs", detailText: nil, image: UIImage.createArtwork(with: UIImage.musicalNotes, iconSizeType: .small, switchColors: true), accessoryImage: nil, accessoryType: .disclosureIndicator)
        section.handler = { [weak self] item, completion in
            guard let `self` = self else { completion(); return }
            var songItems = [CPListItem]()
            songItems.append(self.createPlayShuffledListItem(playContext: PlayContext(containable: artist, playables: artist.playables.filterCached(dependigOn: self.isOfflineMode)), treeDepth: treeDepth+1))
            let artistSongs = artist.playables.filterCached(dependigOn: self.isOfflineMode).sortByTitle().prefix(LibraryStorage.carPlayMaxElements)
            for (index, song) in artistSongs.enumerated() {
                let listItem = self.createDetailTemplate(for: song, playContext: PlayContext(containable: artist, index: index, playables: Array(artistSongs)), treeDepth: treeDepth+1)
                songItems.append(listItem)
            }
            let albumTemplate = CPListTemplate(title: artist.name, sections: [
                CPListSection(items: songItems)
            ])
            self.interfaceController?.pushTemplate(albumTemplate, animated: true, completion: nil)
            completion()
        }
        return section
    }
    
    private func createDetailTemplate(for album: Album, treeDepth: Int) -> CPListItem {
        let section = CPListItem(text: album.name, detailText: album.subtitle, image: album.image(setting: artworkDisplayPreference), accessoryImage: nil, accessoryType: .disclosureIndicator)
        section.handler = { [weak self] item, completion in
            guard let `self` = self else { completion(); return }
            var songItems = [CPListItem]()
            songItems.append(self.createPlayShuffledListItem(playContext: PlayContext(containable: album, playables: album.playables.filterCached(dependigOn: self.isOfflineMode)), treeDepth: treeDepth+1))
            let albumSongs = album.playables.filterCached(dependigOn: self.isOfflineMode).prefix(LibraryStorage.carPlayMaxElements)
            for (index, song) in albumSongs.enumerated() {
                let listItem = self.createDetailTemplate(for: song, playContext: PlayContext(containable: album, index: index, playables: Array(albumSongs)), treeDepth: treeDepth+1, isTrackDisplayed: true)
                songItems.append(listItem)
            }
            let albumTemplate = CPListTemplate(title: album.name, sections: [
                CPListSection(items: songItems)
            ])
            self.interfaceController?.pushTemplate(albumTemplate, animated: true, completion: nil)
            completion()
        }
        return section
    }
    
    private func createPlaylistsSections(treeDepth: Int) -> [CPListTemplateItem] {
        var sections = [CPListTemplateItem]()
        let playlists = appDelegate.library.getPlaylistsForCarPlay(sortType: .lastPlayed, onlyCached: self.isOfflineMode)
        for playlist in playlists {
            let section = CPListItem(text: playlist.name, detailText: playlist.subtitle, image: nil, accessoryImage: nil, accessoryType: .disclosureIndicator)
            section.handler = { [weak self] item, completion in
                guard let `self` = self else { completion(); return }
                var songItems = [CPListItem]()
                songItems.append(self.createPlayShuffledListItem(playContext: PlayContext(containable: playlist, playables: playlist.playables.filterCached(dependigOn: self.isOfflineMode)), treeDepth: treeDepth+1))
                let allSongs = playlist.playables.filterCached(dependigOn: self.isOfflineMode)
                for (index, song) in allSongs.enumerated() {
                    let listItem = self.createDetailTemplate(for: song, playContext: PlayContext(containable: playlist, index: index, playables: allSongs), treeDepth: treeDepth+1)
                    songItems.append(listItem)
                }
                let playlistTemplate = CPListTemplate(title: playlist.name, sections: [
                    CPListSection(items: songItems)
                ])
                self.interfaceController?.pushTemplate(playlistTemplate, animated: true, completion: nil)
                completion()
            }
            sections.append(section)
        }
        return sections
    }
    
    private func createPodcastsSections(treeDepth: Int) -> [CPListTemplateItem] {
        var sections = [CPListTemplateItem]()
        let podcasts = appDelegate.library.getPodcastsForCarPlay(onlyCached: self.isOfflineMode)
        for podcast in podcasts {
            let section = CPListItem(text: podcast.title, detailText: podcast.subtitle, image: podcast.image(setting: artworkDisplayPreference), accessoryImage: nil, accessoryType: .disclosureIndicator)
            section.handler = { [weak self] item, completion in
                guard let `self` = self else { completion(); return }
                var episodeItems = [CPListItem]()
                let allEpisodes = podcast.episodes.filterCached(dependigOn: self.isOfflineMode)
                for episode in allEpisodes {
                    let listItem = self.createDetailTemplate(for: episode, treeDepth: treeDepth+1)
                    episodeItems.append(listItem)
                }
                let podcastTemplate = CPListTemplate(title: podcast.title, sections: [
                    CPListSection(items: episodeItems)
                ])
                self.interfaceController?.pushTemplate(podcastTemplate, animated: true, completion: nil)
                completion()
            }
            sections.append(section)
        }
        return sections
    }

    private func createPlayShuffledListItem(playContext: PlayContext, treeDepth: Int, text: String = "Shuffle") -> CPListItem {
        let img = UIImage.createArtwork(with: UIImage.shuffle, iconSizeType: .small, switchColors: true)
        let listItem = CPListItem(text: text, detailText: nil, image: img)
        listItem.handler = { [weak self] item, completion in
            guard let `self` = self else { completion(); return }
            self.appDelegate.player.playShuffled(context: playContext)
            if treeDepth < Self.maxTreeDepth {
                self.interfaceController?.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
            }
            completion()
        }
        return listItem
    }
    
    private func createDetailTemplate(for episode: PodcastEpisode, treeDepth: Int) -> CPListItem {
        let accessoryType: CPListItemAccessoryType = episode.isCached ? .cloud : .none
        let listItem = CPListItem(text: episode.title, detailText: nil, image: nil, accessoryImage: nil, accessoryType: accessoryType)
        listItem.handler = { [weak self] item, completion in
            guard let `self` = self else { completion(); return }
            self.appDelegate.player.play(context: PlayContext(containable: episode))
            if treeDepth < Self.maxTreeDepth {
                self.interfaceController?.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
            }
            completion()
        }
        return listItem
    }
    
    private func createDetailTemplate(for playable: AbstractPlayable, playContext: PlayContext, treeDepth: Int, isTrackDisplayed: Bool = false) -> CPListItem {
        let accessoryType: CPListItemAccessoryType = playable.isCached ? .cloud : .none
        let image = isTrackDisplayed ? UIImage.numberToImage(number: playable.track) : playable.image(setting: artworkDisplayPreference)
        let listItem = CPListItem(text: playable.title, detailText: playable.subtitle, image: image, accessoryImage: nil, accessoryType: accessoryType)
        listItem.handler = { [weak self] item, completion in
            guard let `self` = self else { completion(); return }
            self.appDelegate.player.play(context: playContext)
            if treeDepth < Self.maxTreeDepth {
                self.interfaceController?.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
            }
            completion()
        }
        return listItem
    }
    
}
