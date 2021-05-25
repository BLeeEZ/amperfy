import UIKit
import CoreData

class IndexesVC: UITableViewController {
    
    var appDelegate: AppDelegate!
    var musicFolder: MusicFolder!
    var index: MusicIndex?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        navigationItem.title = musicFolder.name
        tableView.register(nibName: DirectoryTableCell.typeName)
        tableView.register(nibName: SongTableCell.typeName)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        appDelegate.storage.persistentContainer.performBackgroundTask() { (context) in
            let library = LibraryStorage(context: context)
            let syncer = self.appDelegate.backendApi.createLibrarySyncer()
            let indexAsync = syncer.getIndexes(musicFolder: self.musicFolder, libraryStorage: library)
            DispatchQueue.main.async {
                self.index = indexAsync
                self.index!.songs = indexAsync.songs?.compactMap{ Song(managedObject: self.appDelegate.storage.context.object(with: $0.objectID) as! SongMO) }
                self.tableView.reloadData()
            }
        }
    }
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0.0
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return index?.shortcuts?.count ?? 0
        } else if section == 1 {
            return index?.directories?.count ?? 0
        } else {
            return index?.songs?.count ?? 0
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 {
            return DirectoryTableCell.rowHeight
        } else if indexPath.section == 1 {
            return DirectoryTableCell.rowHeight
        } else {
            return SongTableCell.rowHeight
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell: DirectoryTableCell = dequeueCell(for: tableView, at: indexPath)
            if let shortcut = index?.shortcuts?[indexPath.row] {
                cell.display(directory: shortcut)
            }
            return cell
        } else if indexPath.section == 1 {
            let cell: DirectoryTableCell = dequeueCell(for: tableView, at: indexPath)
            if let directory = index?.directories?[indexPath.row] {
                cell.display(directory: directory)
            }
            return cell
        } else {
            let cell: SongTableCell = dequeueCell(for: tableView, at: indexPath)
            if let song = index?.songs?[indexPath.row] {
                cell.display(song: song, rootView: self)
            }
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.section < 2 else { return }
        
        if indexPath.section == 0, let shortcut = index?.shortcuts?[indexPath.row] {
            performSegue(withIdentifier: Segues.toDirectories.rawValue, sender: shortcut)
        }
        if indexPath.section == 1, let directory = index?.directories?[indexPath.row] {
            performSegue(withIdentifier: Segues.toDirectories.rawValue, sender: directory)
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == Segues.toDirectories.rawValue {
            let vc = segue.destination as! DirectoriesVC
            let musicDirectory = sender as? MusicDirectory
            vc.musicDirectory = musicDirectory
        }
    }

}
