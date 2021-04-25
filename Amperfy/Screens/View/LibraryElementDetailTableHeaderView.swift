import UIKit

class LibraryElementDetailTableHeaderView: UIView {
    
    @IBOutlet weak var playAllButton: UIButton!
    @IBOutlet weak var addAllToPlaylistButton: UIButton!
    
    static let frameHeight: CGFloat = 30.0 + margin.top + margin.bottom
    static let margin = UIView.defaultMarginMiddleElement
    
    private var songContainer: SongContainable?
    private var player: MusicPlayer?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.layoutMargins = Self.margin
    }
    
    @IBAction func playAllButtonPressed(_ sender: Any) {
        guard let songContainer = songContainer, let player = player else { return }
        player.cleanPlaylist()
        player.addToPlaylist(songs: songContainer.songs)
        player.play()
    }
    
    @IBAction func addAllToPlayNextButtonPressed(_ sender: Any) {
        guard let songContainer = songContainer, let player = player else { return }
        player.addToPlaylist(songs: songContainer.songs)
    }
    
    func prepare(songContainer: SongContainable?, with player: MusicPlayer) {
        self.songContainer = songContainer
        self.player = player
    }
    
}
