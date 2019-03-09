import UIKit
import Foundation

class SyncVC: UIViewController, SyncCallbacks {

    var appDelegate: AppDelegate!
    var parsedObjectCount: Int = 0
    var libObjectsToParseCount: Int = 0
    
    @IBOutlet weak var progressBar: UIProgressView!
    @IBOutlet weak var progressLabel: UILabel!
    @IBOutlet weak var progressInfo: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        progressBar.setProgress(0.0, animated: true)
        progressInfo.text = ""
        progressLabel.text = String(format: "%.1f", 0.0) + "%"
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if let objectsToParseCount = appDelegate.ampacheApi.objectsToParseCount {
            libObjectsToParseCount = objectsToParseCount
            if libObjectsToParseCount == 0 {
                notifySyncFinished()
                return
            }
            
            self.appDelegate.backgroundSyncer.stopAndWait()
            self.appDelegate.storage.deleteAmpacheIsSynced()
            self.appDelegate.persistentLibraryStorage.cleanStorage()
            self.appDelegate.reinit()
            
            appDelegate.storage.persistentContainer.performBackgroundTask() { (context) in
                let backgroundLibrary = LibraryStorage(context: context)
                let syncer = LibrarySyncer(ampacheApi: self.appDelegate.ampacheApi)
                syncer.sync(libraryStorage: backgroundLibrary, statusNotifyier: self)
                self.appDelegate.storage.saveAmpacheIsSynced()
                self.appDelegate.backgroundSyncer.start()
            }
        }
    }
    
    private func updateSyncInfo() {
        let percentParsed = Float(self.parsedObjectCount) / Float(self.libObjectsToParseCount)
        self.progressBar.setProgress(percentParsed, animated: true)
        self.progressLabel.text = String(format: "%.1f", percentParsed * 100) + "%"
    }
    
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
        }
    }
    
    func notifyAlbumsSyncStarted() {
        DispatchQueue.main.async { [weak self] in
            self?.progressInfo.text = "Syncing albums ..."
        }
    }
    
    func notifySongsSyncStarted() {
        DispatchQueue.main.async { [weak self] in
            self?.progressInfo.text = "Syncing songs ..."
        }
    }
    
    func notifyPlaylistSyncStarted() {
        DispatchQueue.main.async { [weak self] in
            self?.progressInfo.text = "Syncing playlists ..."
            self?.parsedObjectCount = 0
            self?.updateSyncInfo()
        }
    }
    
    func notifyPlaylistCount(playlistCount: Int)  {
        DispatchQueue.main.async { [weak self] in
            self?.progressInfo.text = "Syncing playlists ..."
            self?.parsedObjectCount = 0
            self?.libObjectsToParseCount = playlistCount
            self?.updateSyncInfo()
        }
    }
    
    func notifySyncFinished() {
        DispatchQueue.main.async { [weak self] in
            self?.performSegue(withIdentifier: "toLibrary", sender: self)
        }
    }
    
}
