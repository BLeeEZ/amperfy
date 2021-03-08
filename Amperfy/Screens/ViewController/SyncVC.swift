import UIKit
import Foundation

class SyncVC: UIViewController {

    var appDelegate: AppDelegate!
    var parsedObjectCount: Int = 0
    var libObjectsToParseCount: Int = 1
    var syncer: LibrarySyncer?
    
    @IBOutlet weak var progressBar: UIProgressView!
    @IBOutlet weak var progressLabel: UILabel!
    @IBOutlet weak var progressInfo: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        progressBar.setProgress(0.0, animated: true)
        progressInfo.text = ""
        progressLabel.text = String(format: "%.1f", 0.0) + "%"
        appDelegate.isKeepScreenAlive = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.appDelegate.backgroundSyncerManager.stopAndWait()
        self.appDelegate.storage.deleteLibraryIsSyncedFlag()
        self.appDelegate.persistentLibraryStorage.cleanStorage()
        self.appDelegate.reinit()
        
        appDelegate.storage.persistentContainer.performBackgroundTask() { (context) in
            let backgroundLibrary = LibraryStorage(context: context)
            self.syncer = self.appDelegate.backendApi.createLibrarySyncer()
            self.syncer?.sync(libraryStorage: backgroundLibrary, statusNotifyier: self)
            self.appDelegate.storage.saveLibraryIsSyncedFlag()
            self.appDelegate.backgroundSyncerManager.start()
        }
    }
    
    private func updateSyncInfo() {
        var percentParsed: Float = 0.0
        if self.libObjectsToParseCount > 0 {
            percentParsed = Float(self.parsedObjectCount) / Float(self.libObjectsToParseCount)
        }
        self.progressBar.setProgress(percentParsed, animated: true)
        self.progressLabel.text = String(format: "%.1f", percentParsed * 100) + "%"
    }

}

extension SyncVC: SyncCallbacks {
    
    func notifyParsedObject() {
        DispatchQueue.main.async { [weak self] in
            if let self = self {
                self.parsedObjectCount += 1
                self.updateSyncInfo()
            }
        }
    }
    
    func notifyArtistSyncStarted() {
        DispatchQueue.main.async { [weak self] in
            self?.progressInfo.text = "Syncing artists ..."
            self?.libObjectsToParseCount = self?.syncer?.artistCount ?? 1
            self?.parsedObjectCount = 0
            self?.updateSyncInfo()
        }
    }
    
    func notifyAlbumsSyncStarted() {
        DispatchQueue.main.async { [weak self] in
            self?.progressInfo.text = "Syncing albums ..."
            self?.libObjectsToParseCount = self?.syncer?.albumCount ?? 1
            self?.parsedObjectCount = 0
            self?.updateSyncInfo()
        }
    }
    
    func notifySongsSyncStarted() {
        DispatchQueue.main.async { [weak self] in
            self?.progressInfo.text = "Syncing songs ..."
            self?.libObjectsToParseCount = self?.syncer?.songCount ?? 1
            self?.parsedObjectCount = 0
            self?.updateSyncInfo()
        }
    }
    
    func notifyPlaylistSyncStarted() {
        DispatchQueue.main.async { [weak self] in
            self?.progressInfo.text = "Syncing playlists ..."
            self?.libObjectsToParseCount = self?.syncer?.playlistCount ?? 1
            self?.parsedObjectCount = 0
            self?.updateSyncInfo()
        }
    }
    
    func notifySyncFinished() {
        DispatchQueue.main.async { [weak self] in
            self?.appDelegate.isKeepScreenAlive = false
            self?.performSegue(withIdentifier: "toLibrary", sender: self)
        }
    }
    
}
