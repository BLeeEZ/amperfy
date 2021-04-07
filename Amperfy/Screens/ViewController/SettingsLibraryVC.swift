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
        
        if #available(iOS 13.0, *) {
            self.cachedSongsCountSpinner.style = .medium
            self.cachedSongsSizeSpinner.style = .medium
        } else {
            self.cachedSongsCountSpinner.style = .gray
            self.cachedSongsSizeSpinner.style = .gray
        }
        
        appDelegate.storage.persistentContainer.performBackgroundTask() { (context) in
            let storage = LibraryStorage(context: context)

            let artists = storage.getArtists()
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.artistsCountLabel.text = String(artists.count)
            }
            
            let albums = storage.getAlbums()
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.albumsCountLabel.text = String(albums.count)
            }
            
            let songs = storage.getSongs()
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.songsCountLabel.text = String(songs.count)
            }
            
            let playlists = storage.getPlaylists()
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.playlistsCountLabel.text = String(playlists.count)
            }

            var cachedSongSizeInKB = songs.filterCached().reduce(0) { $0 + $1.fileData?.sizeInKB }
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.cachedSongsCountSpinner.isHidden = true
                self.cachedSongsCountLabel.text = String(cachedSongs.count)
            }
            
            var cachedSongSizeLabelText = ""
            // This variable name is a bit awkward, blame camelCase. 
            // cachedSongSizeInKBFloat is preferable but reads like kbfloat
            let cachedSongSizeFloatInKB = Float(cachedSongSize)

            // Only calculate cached song sizes in MB or GB when needed
            if cachedSongSizeInKB < 1000000.0 {
                let cachedSongSizeInMB = cachedSongSizeFloatInKB / 1000.0
                cachedSongSizeLabelText = NSString(format: "%.2f", cachedSongSizeInMB) as String + " MB"
            } else {
                let cachedSongSizeInGB = cachedSongSizeInMB / 1000.0
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
