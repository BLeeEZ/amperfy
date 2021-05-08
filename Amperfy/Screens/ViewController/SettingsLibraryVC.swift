import Foundation
import UIKit

class SettingsLibraryVC: UITableViewController {
    
    var appDelegate: AppDelegate!
    
    @IBOutlet weak var artistsCountLabel: UILabel!
    @IBOutlet weak var albumsCountLabel: UILabel!
    @IBOutlet weak var songsCountLabel: UILabel!
    @IBOutlet weak var playlistsCountLabel: UILabel!
    
    @IBOutlet weak var cachedSongsCountLabel: UILabel!
    @IBOutlet weak var cachedSongsCountSpinner: UIActivityIndicatorView!
    @IBOutlet weak var cachedSongsSizeLabel: UILabel!
    @IBOutlet weak var cachedSongsSizeSpinner: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        self.cachedSongsCountSpinner.style = UIActivityIndicatorView.defaultStyle
        
        appDelegate.storage.persistentContainer.performBackgroundTask() { (context) in
            let storage = LibraryStorage(context: context)

            let artistCount = storage.artistCount
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.artistsCountLabel.text = String(artistCount)
            }
            
            let albumCount = storage.albumCount
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.albumsCountLabel.text = String(albumCount)
            }
            
            let songCount = storage.songCount
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.songsCountLabel.text = String(songCount)
            }
            
            let playlistCount = storage.playlistCount
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.playlistsCountLabel.text = String(playlistCount)
            }
            
            let cachedSongCount = storage.cachedSongCount
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.cachedSongsCountSpinner.isHidden = true
                self.cachedSongsCountLabel.text = String(cachedSongCount)
            }
            
            var cachedSongSizeLabelText = ""
            let cachedSongSizeInKB = Float(storage.cachedSongSizeInKB)
            let cachedSongSizeInMB = cachedSongSizeInKB / 1000.0
            let cachedSongSizeInGB = cachedSongSizeInMB / 1000.0
            if cachedSongSizeInMB < 1000.0 {
                cachedSongSizeLabelText = NSString(format: "%.2f", cachedSongSizeInMB) as String + " MB"
            } else {
                cachedSongSizeLabelText = NSString(format: "%.2f", cachedSongSizeInGB) as String + " GB"
            }
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.cachedSongsSizeSpinner.isHidden = true
                self.cachedSongsSizeLabel.text = cachedSongSizeLabelText
            }
        }
    }
    
    @IBAction func deleteSongCachePressed(_ sender: Any) {
        let alert = UIAlertController(title: "Delete song cache", message: "Are you sure to delete all downloaded songs from cache?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Yes", style: .destructive , handler: { _ in
            self.appDelegate.player.stop()
            self.appDelegate.downloadManager.stopAndWait()
            self.appDelegate.persistentLibraryStorage.deleteCompleteSongCache()
            self.appDelegate.persistentLibraryStorage.saveContext()
            self.appDelegate.downloadManager.start()
        }))
        alert.addAction(UIAlertAction(title: "No", style: .default , handler: nil))
        alert.pruneNegativeWidthConstraintsToAvoidFalseConstraintWarnings()
        self.present(alert, animated: true)
    }
    
}
