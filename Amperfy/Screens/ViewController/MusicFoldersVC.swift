import UIKit
import CoreData

class MusicFoldersVC: UITableViewController {
    
    var appDelegate: AppDelegate!
    var musicFolders = [MusicFolder]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        tableView.register(nibName: DirectoryTableCell.typeName)
        tableView.rowHeight = DirectoryTableCell.rowHeight
    }
    
    override func viewWillAppear(_ animated: Bool) {
        appDelegate.storage.persistentContainer.performBackgroundTask() { (context) in
            let syncer = self.appDelegate.backendApi.createLibrarySyncer()
            let folders = syncer.getMusicFolders()
            DispatchQueue.main.async {
                self.musicFolders = folders
                self.tableView.reloadData()
            }
        }
    }
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0.0
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return musicFolders.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: DirectoryTableCell = dequeueCell(for: tableView, at: indexPath)
        cell.display(folder: musicFolders[indexPath.row])
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        performSegue(withIdentifier: Segues.toDirectories.rawValue, sender: musicFolders[indexPath.row])
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == Segues.toDirectories.rawValue {
            let vc = segue.destination as! IndexesVC
            let musicFolder = sender as? MusicFolder
            vc.musicFolder = musicFolder
        }
    }

}
