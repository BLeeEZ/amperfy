import Foundation
import UIKit

private enum Section: Int {
    case completedRequests = 0
    case activeRequests = 1
    case waitingRequests = 2
}

class DownloadsVC: UITableViewController, DownloadViewUpdatable {
    
    var actionButton: UIBarButtonItem!
    var appDelegate: AppDelegate!
    var downloadManager: DownloadManager!
    var requestQueues: DownloadRequestQueues!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        appDelegate.userStatistics.visited(.downloads)
        downloadManager = appDelegate.playableDownloadManager
        requestQueues = downloadManager.requestQueues
        requestQueues.waitingRequests.reverse()
        tableView.register(nibName: PlayableTableCell.typeName)
        tableView.rowHeight = PlayableTableCell.rowHeight
        appDelegate.playableDownloadManager.addNotifier(self)
        actionButton = UIBarButtonItem(title: "...", style: .plain, target: self, action: #selector(performActionButtonOperation))
        navigationItem.rightBarButtonItem = actionButton
    }
    
    @objc private func performActionButtonOperation() {
        let alert = UIAlertController(title: "Downloads", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Cancel all downloads", style: .default, handler: { _ in
            self.downloadManager.cancelDownloads()
            
            self.requestQueues.completedRequests.append(contentsOf: self.requestQueues.activeRequests)
            self.requestQueues.activeRequests = [DownloadRequest]()
            self.requestQueues.completedRequests.append(contentsOf: self.requestQueues.waitingRequests)
            self.requestQueues.waitingRequests = [DownloadRequest]()
            self.tableView.reloadData()
            
        }))
        if requestQueues.completedRequests.count > 0 {
            alert.addAction(UIAlertAction(title: "Scroll to completed downloads", style: .default, handler: { _ in
                if self.requestQueues.completedRequests.count > 0 {
                    self.tableView.scrollToRow(at: IndexPath(row: 0, section: Section.completedRequests.rawValue), at: .top, animated: true)
                }
            }))
        }
        if requestQueues.activeRequests.count > 0 {
            alert.addAction(UIAlertAction(title: "Scroll to active downloads", style: .default, handler: { _ in
                if self.requestQueues.activeRequests.count > 0 {
                    self.tableView.scrollToRow(at: IndexPath(row: 0, section: Section.activeRequests.rawValue), at: .top, animated: true)
                }
            }))
        }
        if requestQueues.waitingRequests.count > 0 {
            alert.addAction(UIAlertAction(title: "Scroll to next downloads", style: .default, handler: { _ in
                if self.requestQueues.waitingRequests.count > 0 {
                    self.tableView.scrollToRow(at: IndexPath(row: 0, section: Section.waitingRequests.rawValue), at: .top, animated: true)
                }
            }))
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.pruneNegativeWidthConstraintsToAvoidFalseConstraintWarnings()
        alert.setOptionsForIPadToDisplayPopupCentricIn(view: self.view)
        present(alert, animated: true, completion: nil)
    }
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return CommonScreenOperations.tableSectionHeightLarge
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var sectionCount = 0
        switch section {
        case Section.completedRequests.rawValue:
            sectionCount = requestQueues.completedRequests.count
        case Section.activeRequests.rawValue:
            sectionCount = requestQueues.activeRequests.count
        case Section.waitingRequests.rawValue:
            sectionCount = requestQueues.waitingRequests.count
        default:
            break
        }
        return sectionCount
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        var sectionTitle = ""
        switch section {
        case Section.completedRequests.rawValue:
            sectionTitle = "Completed"
        case Section.activeRequests.rawValue:
            sectionTitle = "Active"
        case Section.waitingRequests.rawValue:
            sectionTitle = "Next"
        default:
            break
        }
        return sectionTitle
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: PlayableTableCell = dequeueCell(for: tableView, at: indexPath)
        
        var request: DownloadRequest?
        switch indexPath.section {
        case Section.completedRequests.rawValue:
            request = requestQueues.completedRequests[indexPath.row]
        case Section.activeRequests.rawValue:
            request = requestQueues.activeRequests[indexPath.row]
        case Section.waitingRequests.rawValue:
            request = requestQueues.waitingRequests[indexPath.row]
        default:
            break
        }
        
        if let request = request, let playable = request.element as? AbstractPlayable {
            cell.display(playable: playable, rootView: self, download: request.download)
        }

        return cell
    }

    func downloadManager(_ downloadManager: DownloadManager, updatedRequest: DownloadRequest, updateReason: DownloadRequestEvent) {
        switch(updateReason) {
        case .updateProgress:
            let arrayIndices = requestQueues.activeRequests.allIndices(of: updatedRequest)
            for index in arrayIndices {
                if let cell = self.tableView.cellForRow(at: IndexPath(row: index, section: Section.activeRequests.rawValue)) as? PlayableTableCell, let playable = updatedRequest.element as? AbstractPlayable {
                    cell.display(playable: playable, rootView: self, download: updatedRequest.download)
                }
            }
        case .added:
            tableView.beginUpdates()
            var indexPath = IndexPath()
            if updatedRequest.priority == .high {
                requestQueues.waitingRequests.insert(updatedRequest, at: 0)
                indexPath = IndexPath(row: 0, section: Section.waitingRequests.rawValue)
            } else {
                requestQueues.waitingRequests.append(updatedRequest)
                indexPath = IndexPath(row: requestQueues.waitingRequests.count-1, section: Section.waitingRequests.rawValue)
            }
            tableView.insertRows(at: [indexPath], with: .automatic)
            tableView.endUpdates()
        case .removed:
            tableView.beginUpdates()
            let arrayIndices = requestQueues.waitingRequests.allIndices(of: updatedRequest)
            for index in arrayIndices.reversed() {
                requestQueues.waitingRequests.remove(at: index)
                let indexPath = IndexPath(row: index, section: Section.waitingRequests.rawValue)
                tableView.deleteRows(at: [indexPath], with: .automatic)
            }
            tableView.endUpdates()
        case .started:
            tableView.beginUpdates()
            let arrayIndices = requestQueues.waitingRequests.allIndices(of: updatedRequest)
            for index in arrayIndices.reversed() {
                requestQueues.waitingRequests.remove(at: index)
                let indexPath = IndexPath(row: index, section: Section.waitingRequests.rawValue)
                tableView.deleteRows(at: [indexPath], with: .automatic)
            }
            requestQueues.activeRequests.append(updatedRequest)
            tableView.insertRows(at: [IndexPath(row: requestQueues.activeRequests.count-1, section: Section.activeRequests.rawValue)], with: .automatic)
            tableView.endUpdates()
        case .finished:
            tableView.beginUpdates()
            let arrayIndices = requestQueues.activeRequests.allIndices(of: updatedRequest)
            for index in arrayIndices {
                requestQueues.activeRequests.remove(at: index)
                let indexPath = IndexPath(row: index, section: Section.activeRequests.rawValue)
                tableView.deleteRows(at: [indexPath], with: .automatic)
            }
            requestQueues.completedRequests.append(updatedRequest)
            tableView.insertRows(at: [IndexPath(row: requestQueues.completedRequests.count-1, section: Section.completedRequests.rawValue)], with: .automatic)
            tableView.endUpdates()
        }
    }

}
