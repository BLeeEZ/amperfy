import UIKit

class PlaylistSelectorVC: UITableViewController {

    var songToAdd: Song?
    var songsToAdd: [Song]?
    private var appDelegate: AppDelegate!
    private var playlistsAsyncFetch = AsynchronousFetch(result: nil)
    private var playlists = [Playlist]()
    
    private let loadingSpinner = SpinnerViewController()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        tableView.register(nibName: PlaylistTableCell.typeName)
        tableView.rowHeight = PlaylistTableCell.rowHeight
        
        tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.size.width, height: NewPlaylistTableHeader.frameHeight))
        if let newPlaylistTableHeaderView = ViewBuilder<NewPlaylistTableHeader>.createFromNib(withinFixedFrame: CGRect(x: 0, y: 0, width: view.bounds.size.width, height: NewPlaylistTableHeader.frameHeight)) {
            newPlaylistTableHeaderView.reactOnCreation() { _ in
                self.loadingSpinner.display(on: self)
                self.appDelegate.storage.persistentContainer.performBackgroundTask() { (context) in
                    let backgroundLibrary = LibraryStorage(context: context)
                    self.playlistsAsyncFetch = backgroundLibrary.getPlaylistsAsync(forMainContex: self.appDelegate.storage.context) { playlistsResult in
                        self.playlists = playlistsResult.sortAlphabeticallyAscending()
                        self.loadingSpinner.hide()
                        self.tableView.reloadData()
                    }
                }
                
            }
            tableView.tableHeaderView?.addSubview(newPlaylistTableHeaderView)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        loadingSpinner.display(on: self)
        appDelegate.storage.persistentContainer.performBackgroundTask() { (context) in
            let backgroundLibrary = LibraryStorage(context: context)
            self.playlistsAsyncFetch = backgroundLibrary.getPlaylistsAsync(forMainContex: self.appDelegate.storage.context) { playlistsResult in
                self.playlists = playlistsResult.sortAlphabeticallyAscending()
                self.loadingSpinner.hide()
                self.tableView.reloadData()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        self.playlistsAsyncFetch.cancle()
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
