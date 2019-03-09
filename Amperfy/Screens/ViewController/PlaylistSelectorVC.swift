import UIKit

class PlaylistSelectorVC: UITableViewController {

    var songToAdd: Song?
    var songsToAdd: [Song]?
    private var appDelegate: AppDelegate!
    private var playlists = [Playlist]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        playlists = appDelegate.library.getPlaylists().sortAlphabeticallyAscending()
        tableView.register(nibName: PlaylistTableCell.typeName)
        tableView.rowHeight = PlaylistTableCell.rowHeight
        
        if let (fixedView, tableHeader) = ViewBuilder<NewPlaylistTableHeader>.createFromNib(withinFixedFrame: CGRect(x: 0, y: 0, width: view.bounds.size.width, height: NewPlaylistTableHeader.frameHeight)) {
            tableHeader.reactOnCreation() { _ in
                self.playlists = self.appDelegate.library.getPlaylists().sortAlphabeticallyAscending()
                self.tableView.reloadData()
            }
            tableView.tableHeaderView = fixedView
        }
    }
    
    @IBAction func cancelButtonPressed(_ sender: UIBarButtonItem) {
        dismiss()
    }
    
    private func dismiss() {
        dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return playlists.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: PlaylistTableCell = dequeueCell(for: tableView, at: indexPath)
        
        let playlist = playlists[indexPath.row]
        cell.display(playlist: playlist)
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let playlist = playlists[indexPath.row]
        if let song = songToAdd {
            playlist.append(song: song)
        }
        if let songs = songsToAdd {
            playlist.append(songs: songs)
        }
        dismiss()
    }
    
}
