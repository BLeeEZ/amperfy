import UIKit

class LatestSongsVC: UITableViewController {
    
    var actionButton: UIBarButtonItem!
    var appDelegate: AppDelegate!
    var latestSyncWave: SyncWaveMO?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        latestSyncWave = appDelegate.persistentLibraryStorage.getLatestSyncWave()
        tableView.register(nibName: SongTableCell.typeName)
        tableView.rowHeight = SongTableCell.rowHeight
        actionButton = UIBarButtonItem(title: "...", style: .plain, target: self, action: #selector(operateOnAll))
        navigationItem.rightBarButtonItem = actionButton
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.tableView.reloadData()
    }
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return latestSyncWave?.songs.count ?? 0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: SongTableCell = dequeueCell(for: tableView, at: indexPath)
        
        guard let wave = latestSyncWave else { return cell }
        let song = wave.songs[indexPath.row]
        
        cell.display(song: song, rootView: self)
        
        return cell
    }
    
    @objc private func operateOnAll() {
        guard let syncWave = latestSyncWave else { return }
        let alert = UIAlertController(title: "Latest songs", message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Listen later", style: .default, handler: { _ in
            for song in syncWave.songs {
                if !song.isCached {
                    self.appDelegate.downloadManager.download(song: song)
                }
            }
        }))
        if syncWave.hasCachedSongs {
            alert.addAction(UIAlertAction(title: "Remove from cache", style: .default, handler: { _ in
                syncWave.songs.forEach{ song in
                    self.appDelegate.persistentLibraryStorage.deleteCache(ofSong: song)
                }
                self.tableView.reloadData()
            }))
        }
        alert.addAction(UIAlertAction(title: "Add all to playlist", style: .default, handler: { _ in
            let selectPlaylistVC = PlaylistSelectorVC.instantiateFromAppStoryboard()
            selectPlaylistVC.songsToAdd = syncWave.songs
            let selectPlaylistNav = UINavigationController(rootViewController: selectPlaylistVC)
            self.present(selectPlaylistNav, animated: true, completion: nil)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true, completion: nil)
    }
    
}
