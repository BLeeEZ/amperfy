import UIKit
import CoreData

class EventLogVC: SingleFetchedResultsTableViewController<LogEntryMO> {

    private var fetchedResultsController: ErrorLogFetchedResultsController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate.userStatistics.visited(.eventLog)
        
        fetchedResultsController = ErrorLogFetchedResultsController(managedObjectContext: appDelegate.storage.context, isGroupedInAlphabeticSections: false)
        singleFetchedResultsController = fetchedResultsController
        
        tableView.register(nibName: LogEntryTableCell.typeName)
        tableView.rowHeight = LogEntryTableCell.rowHeight
    }
    
    override func viewWillAppear(_ animated: Bool) {
        fetchedResultsController.fetch()
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: LogEntryTableCell = dequeueCell(for: tableView, at: indexPath)
        let entry = fetchedResultsController.getWrappedEntity(at: indexPath)
        cell.display(entry: entry)
        return cell
    }
    
}

