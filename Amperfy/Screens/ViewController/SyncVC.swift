import UIKit
import Foundation

class SyncVC: UIViewController {

    var appDelegate: AppDelegate!
    var state: ParsedObjectType = .genre
    let syncSemaphore = DispatchSemaphore(value: 1)
    var parsedObjectCount: Int = 0
    var parsedObjectPercent: Float = 0.0
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
        self.appDelegate.eventLogger.supressAlerts = true
        self.appDelegate.scrobbleSyncer.stopAndWait()
        self.appDelegate.backgroundLibrarySyncer.stopAndWait()
        self.appDelegate.artworkDownloadManager.stopAndWait()
        self.appDelegate.playableDownloadManager.stopAndWait()
        self.appDelegate.persistentStorage.isLibrarySynced = false
        self.appDelegate.library.cleanStorage()
        self.appDelegate.reinit()
        
        appDelegate.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
            self.syncer = self.appDelegate.backendApi.createLibrarySyncer()
            self.syncer?.sync(currentContext: context, persistentContainer: self.appDelegate.persistentStorage.persistentContainer, statusNotifyier: self)
            self.appDelegate.persistentStorage.librarySyncVersion = .newestVersion
            self.appDelegate.persistentStorage.isLibrarySynced = true
            self.appDelegate.playableDownloadManager.start()
            self.appDelegate.artworkDownloadManager.start()
            self.appDelegate.backgroundLibrarySyncer.start()
        }
    }
    
    private func updateSyncInfo(infoText: String? = nil, percentParsed: Float = 0.0) {
        DispatchQueue.main.async {
            if let infoText = infoText {
                self.progressInfo.text = infoText
            }
            self.progressBar.setProgress(percentParsed, animated: true)
            self.progressLabel.text = String(format: "%.1f", percentParsed * 100) + "%"
        }
    }

}

extension SyncVC: SyncCallbacks {
    
    func notifyParsedObject(ofType parsedObjectType: ParsedObjectType) {
        syncSemaphore.wait()
        guard parsedObjectType == state else {
            syncSemaphore.signal()
            return
        }
        self.parsedObjectCount += 1
        
        var parsePercent: Float = 0.0
        if self.libObjectsToParseCount > 0 {
            parsePercent = Float(self.parsedObjectCount) / Float(self.libObjectsToParseCount)
        }
        let percentDiff = Int(parsePercent*1000)-Int(self.parsedObjectPercent*1000)
        if percentDiff > 0 {
            self.updateSyncInfo(percentParsed: parsePercent)
        }
        self.parsedObjectPercent = parsePercent
        syncSemaphore.signal()
    }
    
    func notifySyncStarted(ofType parsedObjectType: ParsedObjectType) {
        syncSemaphore.wait()
        self.parsedObjectCount = 0
        self.parsedObjectPercent = 0.0
        self.state = parsedObjectType
        
        switch parsedObjectType {
        case .artist:
            self.libObjectsToParseCount = self.syncer?.artistCount ?? 1
            self.updateSyncInfo(infoText: "Syncing artists ...", percentParsed: 0.0)
        case .album:
            self.libObjectsToParseCount = self.syncer?.albumCount ?? 1
            self.updateSyncInfo(infoText: "Syncing albums ...", percentParsed: 0.0)
        case .song:
            self.libObjectsToParseCount = self.syncer?.songCount ?? 1
            self.updateSyncInfo(infoText: "Syncing songs ...", percentParsed: 0.0)
        case .playlist:
            self.libObjectsToParseCount = self.syncer?.playlistCount ?? 1
            self.updateSyncInfo(infoText: "Syncing playlists ...", percentParsed: 0.0)
        case .genre:
            self.libObjectsToParseCount = self.syncer?.genreCount ?? 1
            self.updateSyncInfo(infoText: "Syncing genres ...", percentParsed: 0.0)
        case .podcast:
            self.libObjectsToParseCount = self.syncer?.podcastCount ?? 1
            self.updateSyncInfo(infoText: "Syncing podcasts ...", percentParsed: 0.0)
        }
        syncSemaphore.signal()
    }
    
    func notifySyncFinished() {
        DispatchQueue.main.async { [weak self] in
            self?.appDelegate.isKeepScreenAlive = false
            self?.appDelegate.eventLogger.supressAlerts = false
            self?.performSegue(withIdentifier: "toLibrary", sender: self)
        }
    }
    
}
