//
//  FetchedResultsControllers.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 16.04.21.
//  Copyright (c) 2021 Maximilian Bauer. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation
import CoreData

public enum ElementSortType: Int {
    case name = 0
    case rating = 1
    
    public static let defaultValue: ElementSortType = .name
}

public enum PlaylistSortType: Int {
    case name = 0
    case lastPlayed = 1
    case lastChanged = 2
    
    static let defaultValue: PlaylistSortType = .name
}

public enum DisplayCategoryFilter {
    case all
    case recentlyAdded
    case favorites
}

public class PodcastFetchedResultsController: CachedFetchedResultsController<PodcastMO> {
    
    public init(coreDataCompanion: CoreDataCompanion, isGroupedInAlphabeticSections: Bool) {
        let fetchRequest = PodcastMO.identifierSortedFetchRequest
        fetchRequest.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
            AbstractLibraryEntityMO.excludeRemoteDeleteFetchPredicate,
            coreDataCompanion.library.getFetchPredicate(onlyCachedPodcasts: true),
        ])
        super.init(coreDataCompanion: coreDataCompanion, fetchRequest: fetchRequest, isGroupedInAlphabeticSections: isGroupedInAlphabeticSections)
    }
        
    public func search(searchText: String, onlyCached: Bool) {
        if searchText.count > 0 || onlyCached {
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSCompoundPredicate(orPredicateWithSubpredicates: [
                    AbstractLibraryEntityMO.excludeRemoteDeleteFetchPredicate,
                    coreDataCompanion.library.getFetchPredicate(onlyCachedPodcasts: true),
                ]),
                PodcastMO.getIdentifierBasedSearchPredicate(searchText: searchText),
                coreDataCompanion.library.getFetchPredicate(onlyCachedPodcasts: onlyCached)
            ])
            search(predicate: predicate)
        } else {
            showAllResults()
        }
    }

}

public class PodcastEpisodesReleaseDateFetchedResultsController: BasicFetchedResultsController<PodcastEpisodeMO> {
    
    public init(coreDataCompanion: CoreDataCompanion, isGroupedInAlphabeticSections: Bool) {
        let fetchRequest = PodcastEpisodeMO.publishedDateSortedFetchRequest
        fetchRequest.predicate = coreDataCompanion.library.getFetchPredicateForUserAvailableEpisodes()
        super.init(coreDataCompanion: coreDataCompanion, fetchRequest: fetchRequest, isGroupedInAlphabeticSections: isGroupedInAlphabeticSections)
    }
    
    public func search(searchText: String, onlyCachedSongs: Bool) {
        if searchText.count > 0 || onlyCachedSongs {
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                coreDataCompanion.library.getFetchPredicateForUserAvailableEpisodes(),
                PodcastEpisodeMO.getIdentifierBasedSearchPredicate(searchText: searchText),
                coreDataCompanion.library.getFetchPredicate(onlyCachedPodcastEpisodes: onlyCachedSongs)
            ])
            search(predicate: predicate)
        } else {
            showAllResults()
        }
    }

}

public class PodcastEpisodesFetchedResultsController: BasicFetchedResultsController<PodcastEpisodeMO> {
    
    let podcast: Podcast
    
    public init(forPodcast podcast: Podcast, coreDataCompanion: CoreDataCompanion, isGroupedInAlphabeticSections: Bool) {
        self.podcast = podcast
        let fetchRequest = PodcastEpisodeMO.publishedDateSortedFetchRequest
        fetchRequest.predicate = coreDataCompanion.library.getFetchPredicateForUserAvailableEpisodes(forPodcast: podcast)
        super.init(coreDataCompanion: coreDataCompanion, fetchRequest: fetchRequest, isGroupedInAlphabeticSections: isGroupedInAlphabeticSections)
    }
    
    public func search(searchText: String, onlyCachedSongs: Bool) {
        if searchText.count > 0 || onlyCachedSongs {
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                coreDataCompanion.library.getFetchPredicateForUserAvailableEpisodes(forPodcast: podcast),
                PodcastEpisodeMO.getIdentifierBasedSearchPredicate(searchText: searchText),
                coreDataCompanion.library.getFetchPredicate(onlyCachedPodcastEpisodes: onlyCachedSongs)
            ])
            search(predicate: predicate)
        } else {
            showAllResults()
        }
    }

}

public class GenreFetchedResultsController: CachedFetchedResultsController<GenreMO> {
    
    public init(coreDataCompanion: CoreDataCompanion, isGroupedInAlphabeticSections: Bool) {
        let fetchRequest = GenreMO.identifierSortedFetchRequest
        super.init(coreDataCompanion: coreDataCompanion, fetchRequest: fetchRequest, isGroupedInAlphabeticSections: isGroupedInAlphabeticSections)
    }
        
    public func search(searchText: String, onlyCached: Bool) {
        if searchText.count > 0 || onlyCached {
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                GenreMO.getIdentifierBasedSearchPredicate(searchText: searchText),
                NSCompoundPredicate(orPredicateWithSubpredicates: [
                    coreDataCompanion.library.getFetchPredicate(onlyCachedGenreArtists: onlyCached),
                    coreDataCompanion.library.getFetchPredicate(onlyCachedGenreAlbums: onlyCached),
                    coreDataCompanion.library.getFetchPredicate(onlyCachedGenreSongs: onlyCached)
                ])
            ])
            search(predicate: predicate)
        } else {
            showAllResults()
        }
    }

}

public class GenreArtistsFetchedResultsController: BasicFetchedResultsController<ArtistMO> {
    
    let genre: Genre
    
    public init(for genre: Genre, coreDataCompanion: CoreDataCompanion, isGroupedInAlphabeticSections: Bool) {
        self.genre = genre
        let fetchRequest = ArtistMO.identifierSortedFetchRequest
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSCompoundPredicate(orPredicateWithSubpredicates: [
                AbstractLibraryEntityMO.excludeRemoteDeleteFetchPredicate,
                coreDataCompanion.library.getFetchPredicate(onlyCachedArtists: true)
            ]),
            coreDataCompanion.library.getFetchPredicate(forGenre: genre)
        ])
        super.init(coreDataCompanion: coreDataCompanion, fetchRequest: fetchRequest, isGroupedInAlphabeticSections: isGroupedInAlphabeticSections)
    }
    
    public func search(searchText: String, onlyCached: Bool) {
        if searchText.count > 0 || onlyCached {
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSCompoundPredicate(orPredicateWithSubpredicates: [
                    AbstractLibraryEntityMO.excludeRemoteDeleteFetchPredicate,
                    coreDataCompanion.library.getFetchPredicate(onlyCachedArtists: true)
                ]),
                coreDataCompanion.library.getFetchPredicate(forGenre: genre),
                coreDataCompanion.library.getFetchPredicate(onlyCachedArtists: onlyCached),
                ArtistMO.getIdentifierBasedSearchPredicate(searchText: searchText)
            ])
            search(predicate: predicate)
        } else {
            showAllResults()
        }
    }

}

public class GenreAlbumsFetchedResultsController: BasicFetchedResultsController<AlbumMO> {
    
    let genre: Genre
    
    public init(for genre: Genre, coreDataCompanion: CoreDataCompanion, isGroupedInAlphabeticSections: Bool) {
        self.genre = genre
        let fetchRequest = AlbumMO.identifierSortedFetchRequest
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSCompoundPredicate(orPredicateWithSubpredicates: [
                AbstractLibraryEntityMO.excludeRemoteDeleteFetchPredicate,
                coreDataCompanion.library.getFetchPredicate(onlyCachedAlbums: true)
            ]),
            coreDataCompanion.library.getFetchPredicate(forGenre: genre)
        ])
        super.init(coreDataCompanion: coreDataCompanion, fetchRequest: fetchRequest, isGroupedInAlphabeticSections: isGroupedInAlphabeticSections)
    }
    
    public func search(searchText: String, onlyCached: Bool) {
        if searchText.count > 0 || onlyCached {
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSCompoundPredicate(orPredicateWithSubpredicates: [
                    AbstractLibraryEntityMO.excludeRemoteDeleteFetchPredicate,
                    coreDataCompanion.library.getFetchPredicate(onlyCachedAlbums: true)
                ]),
                coreDataCompanion.library.getFetchPredicate(forGenre: genre),
                coreDataCompanion.library.getFetchPredicate(onlyCachedAlbums: onlyCached),
                ArtistMO.getIdentifierBasedSearchPredicate(searchText: searchText)
            ])
            search(predicate: predicate)
        } else {
            showAllResults()
        }
    }

}

public class GenreSongsFetchedResultsController: BasicFetchedResultsController<SongMO> {
    
    let genre: Genre
    
    public init(for genre: Genre, coreDataCompanion: CoreDataCompanion, isGroupedInAlphabeticSections: Bool) {
        self.genre = genre
        let fetchRequest = SongMO.identifierSortedFetchRequest
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            SongMO.excludeServerDeleteUncachedSongsFetchPredicate,
            coreDataCompanion.library.getFetchPredicate(forGenre: genre)
        ])
        super.init(coreDataCompanion: coreDataCompanion, fetchRequest: fetchRequest, isGroupedInAlphabeticSections: isGroupedInAlphabeticSections)
    }
    
    public func search(searchText: String, onlyCachedSongs: Bool) {
        if searchText.count > 0 || onlyCachedSongs {
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                SongMO.excludeServerDeleteUncachedSongsFetchPredicate,
                coreDataCompanion.library.getFetchPredicate(forGenre: genre),
                SongMO.getIdentifierBasedSearchPredicate(searchText: searchText),
                coreDataCompanion.library.getFetchPredicate(onlyCachedSongs: onlyCachedSongs)
            ])
            search(predicate: predicate)
        } else {
            showAllResults()
        }
    }

}

public class ArtistFetchedResultsController: CachedFetchedResultsController<ArtistMO> {
    
    public init(coreDataCompanion: CoreDataCompanion, sortType: ElementSortType, isGroupedInAlphabeticSections: Bool) {
        var fetchRequest = ArtistMO.identifierSortedFetchRequest
        switch sortType {
        case .name:
            fetchRequest = ArtistMO.identifierSortedFetchRequest
        case .rating:
            fetchRequest = ArtistMO.ratingSortedFetchRequest
        }
        fetchRequest.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
            AbstractLibraryEntityMO.excludeRemoteDeleteFetchPredicate,
            coreDataCompanion.library.getFetchPredicate(onlyCachedArtists: true)
        ])
        super.init(coreDataCompanion: coreDataCompanion, fetchRequest: fetchRequest, sortType: sortType, isGroupedInAlphabeticSections: isGroupedInAlphabeticSections)
    }
    
    public func search(searchText: String, onlyCached: Bool, displayFilter: DisplayCategoryFilter) {
        if searchText.count > 0 || onlyCached || displayFilter != .all {
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSCompoundPredicate(orPredicateWithSubpredicates: [
                    AbstractLibraryEntityMO.excludeRemoteDeleteFetchPredicate,
                    coreDataCompanion.library.getFetchPredicate(onlyCachedArtists: true)
                ]),
                ArtistMO.getIdentifierBasedSearchPredicate(searchText: searchText),
                coreDataCompanion.library.getFetchPredicate(onlyCachedArtists: onlyCached),
                coreDataCompanion.library.getFetchPredicate(artistsDisplayFilter: displayFilter)
            ])
            search(predicate: predicate)
        } else {
            showAllResults()
        }
    }

}

public class ArtistAlbumsItemsFetchedResultsController: BasicFetchedResultsController<AlbumMO> {

    let artist: Artist
    
    public init(for artist: Artist, coreDataCompanion: CoreDataCompanion, isGroupedInAlphabeticSections: Bool) {
        self.artist = artist
        let fetchRequest = AlbumMO.releaseYearSortedFetchRequest
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSCompoundPredicate(orPredicateWithSubpredicates: [
                AbstractLibraryEntityMO.excludeRemoteDeleteFetchPredicate,
                coreDataCompanion.library.getFetchPredicate(onlyCachedAlbums: true)
            ]),
            NSCompoundPredicate(orPredicateWithSubpredicates: [
                coreDataCompanion.library.getFetchPredicate(forArtist: artist),
                AlbumMO.getFetchPredicateForAlbumsWhoseSongsHave(artist: artist)
            ])
        ])
        super.init(coreDataCompanion: coreDataCompanion, fetchRequest: fetchRequest, isGroupedInAlphabeticSections: isGroupedInAlphabeticSections)
    }

    public func search(searchText: String, onlyCached: Bool) {
        if searchText.count > 0 || onlyCached {
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSCompoundPredicate(orPredicateWithSubpredicates: [
                    AbstractLibraryEntityMO.excludeRemoteDeleteFetchPredicate,
                    coreDataCompanion.library.getFetchPredicate(onlyCachedAlbums: true)
                ]),
                NSCompoundPredicate(orPredicateWithSubpredicates: [
                    coreDataCompanion.library.getFetchPredicate(forArtist: artist),
                    AlbumMO.getFetchPredicateForAlbumsWhoseSongsHave(artist: artist)
                ]),
                coreDataCompanion.library.getFetchPredicate(onlyCachedAlbums: onlyCached),
                ArtistMO.getIdentifierBasedSearchPredicate(searchText: searchText)
            ])
            search(predicate: predicate)
        } else {
            showAllResults()
        }
    }

}

public class ArtistSongsItemsFetchedResultsController: BasicFetchedResultsController<SongMO> {

    let artist: Artist
    
    public init(for artist: Artist, coreDataCompanion: CoreDataCompanion, isGroupedInAlphabeticSections: Bool) {
        self.artist = artist
        let fetchRequest = SongMO.identifierSortedFetchRequest
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            SongMO.excludeServerDeleteUncachedSongsFetchPredicate,
            coreDataCompanion.library.getFetchPredicate(forArtist: artist)
        ])
        super.init(coreDataCompanion: coreDataCompanion, fetchRequest: fetchRequest, isGroupedInAlphabeticSections: isGroupedInAlphabeticSections)
    }

    public func search(searchText: String, onlyCachedSongs: Bool) {
        if searchText.count > 0 || onlyCachedSongs {
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                SongMO.excludeServerDeleteUncachedSongsFetchPredicate,
                coreDataCompanion.library.getFetchPredicate(forArtist: artist),
                SongMO.getIdentifierBasedSearchPredicate(searchText: searchText),
                coreDataCompanion.library.getFetchPredicate(onlyCachedSongs: onlyCachedSongs)
            ])
            search(predicate: predicate)
        } else {
            showAllResults()
        }
    }

}

public class AlbumFetchedResultsController: CachedFetchedResultsController<AlbumMO> {
    
    public init(coreDataCompanion: CoreDataCompanion, sortType: ElementSortType, isGroupedInAlphabeticSections: Bool) {
        var fetchRequest = AlbumMO.identifierSortedFetchRequest
        switch sortType {
        case .name:
            fetchRequest = AlbumMO.identifierSortedFetchRequest
        case .rating:
            fetchRequest = AlbumMO.ratingSortedFetchRequest
        }
        fetchRequest.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
            AbstractLibraryEntityMO.excludeRemoteDeleteFetchPredicate,
            coreDataCompanion.library.getFetchPredicate(onlyCachedAlbums: true)
        ])
        super.init(coreDataCompanion: coreDataCompanion, fetchRequest: fetchRequest, sortType: sortType, isGroupedInAlphabeticSections: isGroupedInAlphabeticSections)
    }
    
    public func search(searchText: String, onlyCached: Bool, displayFilter: DisplayCategoryFilter) {
        if searchText.count > 0 || onlyCached || displayFilter != .all {
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSCompoundPredicate(orPredicateWithSubpredicates: [
                    AbstractLibraryEntityMO.excludeRemoteDeleteFetchPredicate,
                    coreDataCompanion.library.getFetchPredicate(onlyCachedAlbums: true)
                ]),
                AlbumMO.getIdentifierBasedSearchPredicate(searchText: searchText),
                coreDataCompanion.library.getFetchPredicate(onlyCachedAlbums: onlyCached),
                coreDataCompanion.library.getFetchPredicate(albumsDisplayFilter: displayFilter)
            ])
            search(predicate: predicate)
        } else {
            showAllResults()
        }
    }

}

public class SongsFetchedResultsController: CachedFetchedResultsController<SongMO> {
    
    public init(coreDataCompanion: CoreDataCompanion, sortType: ElementSortType, isGroupedInAlphabeticSections: Bool) {
        var fetchRequest = SongMO.identifierSortedFetchRequest
        switch sortType {
        case .name:
            fetchRequest = SongMO.identifierSortedFetchRequest
        case .rating:
            fetchRequest = SongMO.ratingSortedFetchRequest
        }
        fetchRequest.predicate = SongMO.excludeServerDeleteUncachedSongsFetchPredicate
        super.init(coreDataCompanion: coreDataCompanion, fetchRequest: fetchRequest, sortType: sortType, isGroupedInAlphabeticSections: isGroupedInAlphabeticSections)
        keepAllResultsUpdated = false
    }
    
    public func search(searchText: String, onlyCachedSongs: Bool, displayFilter: DisplayCategoryFilter) {
        if searchText.count > 0 || onlyCachedSongs || displayFilter != .all {
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                SongMO.excludeServerDeleteUncachedSongsFetchPredicate,
                SongMO.getIdentifierBasedSearchPredicate(searchText: searchText),
                coreDataCompanion.library.getFetchPredicate(onlyCachedSongs: onlyCachedSongs),
                coreDataCompanion.library.getFetchPredicate(songsDisplayFilter: displayFilter)
            ])
            search(predicate: predicate)
        } else {
            showAllResults()
        }
    }

}

public class AlbumSongsFetchedResultsController: BasicFetchedResultsController<SongMO> {
    
    let album: Album
    
    public init(forAlbum album: Album, coreDataCompanion: CoreDataCompanion, isGroupedInAlphabeticSections: Bool) {
        self.album = album
        let fetchRequest = SongMO.trackNumberSortedFetchRequest
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            SongMO.excludeServerDeleteUncachedSongsFetchPredicate,
            coreDataCompanion.library.getFetchPredicate(forAlbum: album)
        ])
        super.init(coreDataCompanion: coreDataCompanion, fetchRequest: fetchRequest, isGroupedInAlphabeticSections: isGroupedInAlphabeticSections)
    }
    
    public func search(searchText: String, onlyCachedSongs: Bool) {
        if searchText.count > 0 || onlyCachedSongs {
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                SongMO.excludeServerDeleteUncachedSongsFetchPredicate,
                coreDataCompanion.library.getFetchPredicate(forAlbum: album),
                SongMO.getIdentifierBasedSearchPredicate(searchText: searchText),
                coreDataCompanion.library.getFetchPredicate(onlyCachedSongs: onlyCachedSongs)
            ])
            search(predicate: predicate)
        } else {
            showAllResults()
        }
    }

}

public class PlaylistItemsFetchedResultsController: BasicFetchedResultsController<PlaylistItemMO> {

    let playlist: Playlist
    
    public init(forPlaylist playlist: Playlist, coreDataCompanion: CoreDataCompanion, isGroupedInAlphabeticSections: Bool) {
        self.playlist = playlist
        let fetchRequest = PlaylistItemMO.playlistOrderSortedFetchRequest
        fetchRequest.predicate = coreDataCompanion.library.getFetchPredicate(forPlaylist: playlist)
        super.init(coreDataCompanion: coreDataCompanion, fetchRequest: fetchRequest, isGroupedInAlphabeticSections: isGroupedInAlphabeticSections)
    }
    
    public func search(onlyCachedSongs: Bool) {
        if onlyCachedSongs {
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                coreDataCompanion.library.getFetchPredicate(forPlaylist: playlist),
                coreDataCompanion.library.getFetchPredicate(onlyCachedPlaylistItems: onlyCachedSongs)
            ])
            search(predicate: predicate)
        } else {
            showAllResults()
        }
    }

}

public class PlaylistFetchedResultsController: BasicFetchedResultsController<PlaylistMO> {

    var sortType: PlaylistSortType
    
    public init(coreDataCompanion: CoreDataCompanion, sortType: PlaylistSortType, isGroupedInAlphabeticSections: Bool) {
        self.sortType = sortType
        var fetchRequest = PlaylistMO.identifierSortedFetchRequest
        switch sortType {
        case .name:
            fetchRequest = PlaylistMO.identifierSortedFetchRequest
        case .lastPlayed:
            fetchRequest = PlaylistMO.lastPlayedDateFetchRequest
        case .lastChanged:
            fetchRequest = PlaylistMO.lastChangedDateFetchRequest
        }
        fetchRequest.predicate = PlaylistMO.excludeSystemPlaylistsFetchPredicate
        super.init(coreDataCompanion: coreDataCompanion, fetchRequest: fetchRequest, isGroupedInAlphabeticSections: isGroupedInAlphabeticSections)
    }
    
    public func search(searchText: String, playlistSearchCategory: PlaylistSearchCategory) {
        if searchText.count > 0 || playlistSearchCategory != .defaultValue {
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                PlaylistMO.excludeSystemPlaylistsFetchPredicate,
                PlaylistMO.getIdentifierBasedSearchPredicate(searchText: searchText),
                coreDataCompanion.library.getFetchPredicate(forPlaylistSearchCategory: playlistSearchCategory)
            ])
            search(predicate: predicate)
        } else {
            showAllResults()
        }
    }

}

public class PlaylistSelectorFetchedResultsController: CachedFetchedResultsController<PlaylistMO> {

    var sortType: PlaylistSortType
    
    public init(coreDataCompanion: CoreDataCompanion, sortType: PlaylistSortType, isGroupedInAlphabeticSections: Bool) {
        self.sortType = sortType
        var fetchRequest = PlaylistMO.identifierSortedFetchRequest
        switch sortType {
        case .name:
            fetchRequest = PlaylistMO.identifierSortedFetchRequest
        case .lastPlayed:
            fetchRequest = PlaylistMO.lastPlayedDateFetchRequest
        case .lastChanged:
            fetchRequest = PlaylistMO.lastChangedDateFetchRequest
        }
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            PlaylistMO.excludeSystemPlaylistsFetchPredicate,
            coreDataCompanion.library.getFetchPredicate(forPlaylistSearchCategory: .userOnly)
        ])
        super.init(coreDataCompanion: coreDataCompanion, fetchRequest: fetchRequest, isGroupedInAlphabeticSections: isGroupedInAlphabeticSections)
    }
    
    public func search(searchText: String) {
        if searchText.count > 0 {
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                PlaylistMO.excludeSystemPlaylistsFetchPredicate,
                PlaylistMO.getIdentifierBasedSearchPredicate(searchText: searchText),
                coreDataCompanion.library.getFetchPredicate(forPlaylistSearchCategory: .userOnly)
            ])
            search(predicate: predicate)
        } else {
            showAllResults()
        }
    }

}

public class ErrorLogFetchedResultsController: BasicFetchedResultsController<LogEntryMO> {

    public init(coreDataCompanion: CoreDataCompanion, isGroupedInAlphabeticSections: Bool) {
        let fetchRequest = LogEntryMO.creationDateSortedFetchRequest
        super.init(coreDataCompanion: coreDataCompanion, fetchRequest: fetchRequest, isGroupedInAlphabeticSections: isGroupedInAlphabeticSections)
    }

}

public class MusicFolderFetchedResultsController: CachedFetchedResultsController<MusicFolderMO> {
    
    public init(coreDataCompanion: CoreDataCompanion, isGroupedInAlphabeticSections: Bool) {
        let fetchRequest = MusicFolderMO.idSortedFetchRequest
        super.init(coreDataCompanion: coreDataCompanion, fetchRequest: fetchRequest, isGroupedInAlphabeticSections: isGroupedInAlphabeticSections)
    }
    
    public func search(searchText: String) {
        if searchText.count > 0 {
            search(predicate: MusicFolderMO.getSearchPredicate(searchText: searchText))
        } else {
            showAllResults()
        }
    }

}

public class MusicFolderDirectoriesFetchedResultsController: BasicFetchedResultsController<DirectoryMO> {
    
    let musicFolder: MusicFolder
    
    public init(for musicFolder: MusicFolder, coreDataCompanion: CoreDataCompanion, isGroupedInAlphabeticSections: Bool) {
        self.musicFolder = musicFolder
        let fetchRequest = DirectoryMO.identifierSortedFetchRequest
        fetchRequest.predicate = coreDataCompanion.library.getFetchPredicate(forMusicFolder: musicFolder)
        super.init(coreDataCompanion: coreDataCompanion, fetchRequest: fetchRequest, isGroupedInAlphabeticSections: isGroupedInAlphabeticSections)
    }

    public func search(searchText: String) {
        if searchText.count > 0 {
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                coreDataCompanion.library.getFetchPredicate(forMusicFolder: musicFolder),
                DirectoryMO.getIdentifierBasedSearchPredicate(searchText: searchText)
            ])
            search(predicate: predicate)
        } else {
            showAllResults()
        }
    }

}

public class DirectorySubdirectoriesFetchedResultsController: BasicFetchedResultsController<DirectoryMO> {
    
    let directory: Directory
    
    public init(for directory: Directory, coreDataCompanion: CoreDataCompanion, isGroupedInAlphabeticSections: Bool) {
        self.directory = directory
        let fetchRequest = DirectoryMO.identifierSortedFetchRequest
        fetchRequest.predicate = coreDataCompanion.library.getDirectoryFetchPredicate(forDirectory: directory)
        super.init(coreDataCompanion: coreDataCompanion, fetchRequest: fetchRequest, isGroupedInAlphabeticSections: isGroupedInAlphabeticSections)
    }

    public func search(searchText: String) {
        if searchText.count > 0 {
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                coreDataCompanion.library.getDirectoryFetchPredicate(forDirectory: directory),
                DirectoryMO.getIdentifierBasedSearchPredicate(searchText: searchText)
            ])
            search(predicate: predicate)
        } else {
            showAllResults()
        }
    }

}


public class DirectorySongsFetchedResultsController: BasicFetchedResultsController<SongMO> {
    
    let directory: Directory

    public init(for directory: Directory, coreDataCompanion: CoreDataCompanion, isGroupedInAlphabeticSections: Bool) {
        self.directory = directory
        let fetchRequest = SongMO.trackNumberSortedFetchRequest
        fetchRequest.predicate = coreDataCompanion.library.getSongFetchPredicate(forDirectory: directory)
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            SongMO.excludeServerDeleteUncachedSongsFetchPredicate,
            coreDataCompanion.library.getSongFetchPredicate(forDirectory: directory)
        ])
        super.init(coreDataCompanion: coreDataCompanion, fetchRequest: fetchRequest, isGroupedInAlphabeticSections: isGroupedInAlphabeticSections)
    }
    
    public func search(searchText: String, onlyCachedSongs: Bool) {
        if searchText.count > 0 || onlyCachedSongs {
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                SongMO.excludeServerDeleteUncachedSongsFetchPredicate,
                coreDataCompanion.library.getSongFetchPredicate(forDirectory: directory),
                SongMO.getIdentifierBasedSearchPredicate(searchText: searchText),
                coreDataCompanion.library.getFetchPredicate(onlyCachedSongs: onlyCachedSongs)
            ])
            search(predicate: predicate)
        } else {
            showAllResults()
        }
    }

}


public class DownloadsFetchedResultsController: BasicFetchedResultsController<DownloadMO> {
    
    public init(coreDataCompanion: CoreDataCompanion, isGroupedInAlphabeticSections: Bool) {
        let fetchRequest: NSFetchRequest<DownloadMO> = DownloadMO.creationDateSortedFetchRequest
        fetchRequest.predicate = DownloadMO.onlyPlayablesPredicate
        super.init(coreDataCompanion: coreDataCompanion, fetchRequest: fetchRequest, isGroupedInAlphabeticSections: isGroupedInAlphabeticSections)
    }

}
