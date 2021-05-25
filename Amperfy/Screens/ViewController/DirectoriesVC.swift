import UIKit
import CoreData

class DirectoriesVC: UITableViewController {
    
    var appDelegate: AppDelegate!
    var musicDirectory: MusicDirectory!

    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        navigationItem.title = musicDirectory.name
        tableView.register(nibName: DirectoryTableCell.typeName)
        tableView.register(nibName: SongTableCell.typeName)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        appDelegate.storage.persistentContainer.performBackgroundTask() { (context) in
            let library = LibraryStorage(context: context)
            let syncer = self.appDelegate.backendApi.createLibrarySyncer()
            let musicDirectoryAsync = syncer.getMusicDirectoryContent(of: self.musicDirectory, libraryStorage: library)
            DispatchQueue.main.async {
                self.musicDirectory = musicDirectoryAsync
                self.musicDirectory.songs = musicDirectoryAsync.songs?.compactMap{ Song(managedObject: self.appDelegate.storage.context.object(with: $0.objectID) as! SongMO) }
                self.tableView.reloadData()
            }
        }
    }
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0.0
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return musicDirectory?.directories?.count ?? 0
        } else {
            return musicDirectory?.songs?.count ?? 0
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell: DirectoryTableCell = dequeueCell(for: tableView, at: indexPath)
            if let directory = musicDirectory?.directories?[indexPath.row] {
                cell.display(directory: directory)
            }
            return cell
        } else {
            let cell: SongTableCell = dequeueCell(for: tableView, at: indexPath)
            if let song = musicDirectory?.songs?[indexPath.row] {
                cell.display(song: song, rootView: self)
            }
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.section == 0 else { return }
        
        if let navController = navigationController, let directory = musicDirectory?.directories?[indexPath.row] {
            let directoriesVC = DirectoriesVC.instantiateFromAppStoryboard()
            directoriesVC.musicDirectory = directory
            navController.pushViewController(directoriesVC, animated: true)
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 {
            return DirectoryTableCell.rowHeight
        } else {
            return SongTableCell.rowHeight
        }
    }

}
