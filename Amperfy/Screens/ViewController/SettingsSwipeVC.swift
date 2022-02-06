import UIKit

class SettingsSwipeVC: UITableViewController {

    var appDelegate: AppDelegate!
    
    private var actionSettings = SwipeActionSettings.defaultSettings

    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        tableView.register(nibName: SwipeActionTableCell.typeName)
        tableView.rowHeight = SwipeActionTableCell.rowHeight
        
        actionSettings = appDelegate.persistentStorage.settings.swipeActionSettings
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.isEditing = true
        tableView.reloadData()
    }

    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "Leading swipe"
        case 1: return "Trailing swipe"
        case 2: return "Not used"
        default: return nil
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return actionSettings.combined[section].count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: SwipeActionTableCell = self.tableView.dequeueCell(for: tableView, at: indexPath)
        cell.display(action: actionSettings.combined[indexPath.section][indexPath.row])
        return cell
    }

    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {
        let fromAction = actionSettings.combined[fromIndexPath.section][fromIndexPath.row]
        actionSettings.combined[fromIndexPath.section].remove(at: fromIndexPath.row)
        actionSettings.combined[to.section].insert(fromAction, at: to.row)
        appDelegate.persistentStorage.settings.swipeActionSettings = actionSettings
    }
    

    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .none
    }
    
    override func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        return false
    }

}
