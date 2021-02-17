import Foundation
import UIKit

class SettingsLibraryVC: UITableViewController {
    
    var appDelegate: AppDelegate!
    
    @IBOutlet weak var artistsCountLabel: UILabel!
    @IBOutlet weak var albumsCountLabel: UILabel!
    @IBOutlet weak var songsCountLabel: UILabel!
    @IBOutlet weak var playlistsCountLabel: UILabel!
    
    @IBOutlet weak var cachedSongsCountLabel: UILabel!
    @IBOutlet weak var cachedSongsSizeLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        
        artistsCountLabel.text = String(appDelegate.library.getArtists().count)
        albumsCountLabel.text = String(appDelegate.library.getAlbums().count)
        let songs = appDelegate.library.getSongs()
        songsCountLabel.text = String(songs.count)
        playlistsCountLabel.text = String(appDelegate.library.getPlaylists().count)
        
        let cachedSongs = songs.filterCached()
        cachedSongsCountLabel.text = String(cachedSongs.count)
        var cachedSongSize = 0
        for song in cachedSongs {
            cachedSongSize += song.fileData?.sizeInKB ?? 0
        }
        let cachedSongSizeFloat = Float(cachedSongSize)
        let cachedSongSizeInMB = cachedSongSizeFloat / 1000.0
        let cachedSongSizeInGB = cachedSongSizeInMB / 1000.0
        if cachedSongSizeInMB < 1000.0 {
            cachedSongsSizeLabel.text = NSString(format: "%.2f", cachedSongSizeInMB) as String + " MB"
        } else {
            cachedSongsSizeLabel.text = NSString(format: "%.2f", cachedSongSizeInGB) as String + " GB"
        }
        
    }
    
    @IBAction func deleteSongCachePressed(_ sender: Any) {
        let alert = UIAlertController(title: "Delete song cache", message: "Are you sure to delete all downloaded songs from cache?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Yes", style: .destructive , handler: { _ in
            self.appDelegate.player.stop()
            self.appDelegate.downloadManager.stopAndWait()
            self.appDelegate.persistentLibraryStorage.deleteCompleteSongCache()
            self.appDelegate.persistentLibraryStorage.saveContext()
        }))
        alert.addAction(UIAlertAction(title: "No", style: .default , handler: nil))
        alert.pruneNegativeWidthConstraintsToAvoidFalseConstraintWarnings()
        self.present(alert, animated: true)
    }
    
}
