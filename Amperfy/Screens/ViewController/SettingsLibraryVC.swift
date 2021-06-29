import Foundation
import UIKit

class SettingsLibraryVC: UITableViewController {
    
    var appDelegate: AppDelegate!
    
    @IBOutlet weak var artistsCountLabel: UILabel!
    @IBOutlet weak var albumsCountLabel: UILabel!
    @IBOutlet weak var songsCountLabel: UILabel!
    @IBOutlet weak var playlistsCountLabel: UILabel!
    @IBOutlet weak var podcastsCountLabel: UILabel!
    @IBOutlet weak var podcastEpisodesCountLabel: UILabel!
    
    @IBOutlet weak var cachedSongsCountLabel: UILabel!
    @IBOutlet weak var cachedSongsCountSpinner: UIActivityIndicatorView!
    @IBOutlet weak var cachedSongsSizeLabel: UILabel!
    @IBOutlet weak var cachedSongsSizeSpinner: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        appDelegate.userStatistics.visited(.settingsLibrary)
        self.cachedSongsCountSpinner.style = UIActivityIndicatorView.defaultStyle
        
        appDelegate.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
            let library = LibraryStorage(context: context)

            let playlistCount = library.playlistCount
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.playlistsCountLabel.text = String(playlistCount)
            }

            let artistCount = library.artistCount
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.artistsCountLabel.text = String(artistCount)
            }
            
            let albumCount = library.albumCount
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.albumsCountLabel.text = String(albumCount)
            }
            
            let podcastCount = library.podcastCount
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.podcastsCountLabel.text = String(podcastCount)
            }
            
            let podcastEpisodeCount = library.podcastEpisodeCount
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.podcastEpisodesCountLabel.text = String(podcastEpisodeCount)
            }
            
            let songCount = library.songCount
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.songsCountLabel.text = String(songCount)
            }
            
            let cachedSongCount = library.cachedSongCount
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.cachedSongsCountSpinner.isHidden = true
                self.cachedSongsCountLabel.text = String(cachedSongCount)
            }
            
            let cachedSongSizeLabelText = library.cachedPlayableSizeInByte.asByteString
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
            self.appDelegate.playableDownloadManager.stopAndWait()
            self.appDelegate.library.deleteCompleteSongCache()
            self.appDelegate.library.saveContext()
            self.appDelegate.playableDownloadManager.start()
        }))
        alert.addAction(UIAlertAction(title: "No", style: .default , handler: nil))
        alert.pruneNegativeWidthConstraintsToAvoidFalseConstraintWarnings()
        self.present(alert, animated: true)
    }
    
}
