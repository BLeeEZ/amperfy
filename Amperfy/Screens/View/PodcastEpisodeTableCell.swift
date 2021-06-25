import UIKit

class PodcastEpisodeTableCell: BasicTableCell {
    
    @IBOutlet weak var podcastEpisodeLabel: UILabel!
    @IBOutlet weak var podcastEpisodeImage: LibraryEntityImage!
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var playEpisodeButton: UIButton!
    @IBOutlet weak var optionsButton: UIButton!
    
    static let rowHeight: CGFloat = 70.0 + margin.bottom + margin.top
    
    private var episode: PodcastEpisode!
    private var rootView: UIViewController?
    
    func display(episode: PodcastEpisode, rootView: UIViewController) {
        self.episode = episode
        self.rootView = rootView
        refresh()
    }

    func refresh() {
        guard let episode = self.episode, let playInfo = episode.playInfo else { return }
        podcastEpisodeLabel.text = playInfo.title
        podcastEpisodeImage.displayAndUpdate(entity: episode, via: appDelegate.artworkDownloadManager)
        
        optionsButton.setTitle(CommonString.threeMiddleDots, for: .normal)
        if episode.userStatus == .syncingOnServer {
            playEpisodeButton.setTitle(FontAwesomeIcon.Ban.asString, for: .normal)
            playEpisodeButton.isEnabled = false
        } else {
            playEpisodeButton.setTitle(FontAwesomeIcon.Play.asString, for: .normal)
            playEpisodeButton.isEnabled = true
        }
        
        var infoText = ""
        infoText += "\(episode.publishDate.asShortDayMonthString) \(CommonString.oneMiddleDot)"
        infoText += " \(episode.userStatus.description) \(CommonString.oneMiddleDot)"
        infoText += " \(playInfo.duration.asDurationString)"
        infoLabel.text = infoText
    }

    @IBAction func playEpisodeButtonPressed(_ sender: Any) {
        guard let episode = self.episode, let playInfo = episode.playInfo else { return }
        appDelegate.player.addToPlaylist(song: playInfo)
        let indexInPlayerPlaylist = appDelegate.player.playlist.songs.count-1
        appDelegate.player.play(songInPlaylistAt: indexInPlayerPlaylist)
    }
    
    @IBAction func optionsButtonPressed(_ sender: Any) {
        guard let episode = self.episode, let playInfo = episode.playInfo, let rootView = rootView else { return }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        let alert = createAlert(forSong: playInfo, rootView: rootView)
        alert.setOptionsForIPadToDisplayPopupCentricIn(view: rootView.view)
        rootView.present(alert, animated: true, completion: nil)
    }
    
    func createAlert(forSong song: Song, rootView: UIViewController) -> UIAlertController {
        let alert = UIAlertController(title: "\n\n\n", message: nil, preferredStyle: .actionSheet)
    
        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: alert.view.bounds.size.width, height: SongActionSheetView.frameHeight))
        if let songActionSheetView = ViewBuilder<SongActionSheetView>.createFromNib(withinFixedFrame: CGRect(x: 0, y: 0, width: alert.view.bounds.size.width, height: SongActionSheetView.frameHeight)) {
            songActionSheetView.display(song: song)
            headerView.addSubview(songActionSheetView)
            alert.view.addSubview(headerView)
        }
    
        if episode.userStatus != .syncingOnServer {
            alert.addAction(UIAlertAction(title: "Play", style: .default, handler: { _ in
                self.appDelegate.player.play(song: song)
            }))
            alert.addAction(UIAlertAction(title: "Add to play next", style: .default, handler: { _ in
                self.appDelegate.player.addToPlaylist(song: song)
            }))
            if song.isCached {
                alert.addAction(UIAlertAction(title: "Remove from cache", style: .default, handler: { _ in
                    self.appDelegate.library.deleteCache(ofSong: song)
                    self.appDelegate.library.saveContext()
                    self.refresh()
                }))
            } else {
                alert.addAction(UIAlertAction(title: "Download", style: .default, handler: { _ in
                    self.appDelegate.songDownloadManager.download(object: song)
                    self.refresh()
                }))
            }
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        } else {
            alert.addAction(UIAlertAction(title: "Episode not available", style: .destructive))
        }
        
        alert.pruneNegativeWidthConstraintsToAvoidFalseConstraintWarnings()
        return alert
    }
    
}
