import Foundation

extension BasicTableViewController {
    
    func fetchDetails(of genre: Genre, completionHandler: @escaping () -> Void) {
        if appDelegate.persistentStorage.settings.isOnlineMode {
            appDelegate.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
                let library = LibraryStorage(context: context)
                let syncer = self.appDelegate.backendApi.createLibrarySyncer()
                syncer.sync(genre: genre, library: library)
                DispatchQueue.main.async {
                    completionHandler()
                }
            }
        } else {
            completionHandler()
        }
    }

    func fetchDetails(of artist: Artist, completionHandler: @escaping () -> Void) {
        if appDelegate.persistentStorage.settings.isOnlineMode {
            appDelegate.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
                let library = LibraryStorage(context: context)
                let syncer = self.appDelegate.backendApi.createLibrarySyncer()
                syncer.sync(artist: artist, library: library)
                DispatchQueue.main.async {
                    completionHandler()
                }
            }
        } else {
            completionHandler()
        }
    }

    func fetchDetails(of album: Album, completionHandler: @escaping () -> Void) {
        if appDelegate.persistentStorage.settings.isOnlineMode {
            appDelegate.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
                let library = LibraryStorage(context: context)
                let syncer = self.appDelegate.backendApi.createLibrarySyncer()
                syncer.sync(album: album, library: library)
                DispatchQueue.main.async {
                    completionHandler()
                }
            }
        } else {
            completionHandler()
        }
    }

    func fetchDetails(of playlist: Playlist, completionHandler: @escaping () -> Void) {
        if appDelegate.persistentStorage.settings.isOnlineMode {
            appDelegate.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
                let syncLibrary = LibraryStorage(context: context)
                let syncer = self.appDelegate.backendApi.createLibrarySyncer()
                let playlistAsync = playlist.getManagedObject(in: context, library: syncLibrary)
                syncer.syncDown(playlist: playlistAsync, library: syncLibrary)
                DispatchQueue.main.async {
                    completionHandler()
                }
            }
        } else {
            completionHandler()
        }
    }

    func fetchDetails(of podcast: Podcast, completionHandler: @escaping () -> Void) {
        if appDelegate.persistentStorage.settings.isOnlineMode {
            appDelegate.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
                let library = LibraryStorage(context: context)
                let syncer = self.appDelegate.backendApi.createLibrarySyncer()
                let podcastAsync = Podcast(managedObject: context.object(with: podcast.managedObject.objectID) as! PodcastMO)
                syncer.sync(podcast: podcastAsync, library: library)
                DispatchQueue.main.async {
                    completionHandler()
                }
            }
        } else {
            completionHandler()
        }
    }

}
