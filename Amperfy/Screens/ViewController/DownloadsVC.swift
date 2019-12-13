import Foundation
import UIKit

private enum Section: Int {
    case queuedRequests = 0
}

class DownloadsVC: UITableViewController, SongDownloadViewUpdatable {
    
    var appDelegate: AppDelegate!
    var downloadManager: DownloadManager!
    var queuedRequests = [DownloadRequest<Song>]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        downloadManager = appDelegate.downloadManager
        queuedRequests = downloadManager.queuedRequests
        tableView.register(nibName: SongTableCell.typeName)
        tableView.rowHeight = SongTableCell.rowHeight
        appDelegate.downloadManager.addNotifier(self)
    }
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return CommonScreenOperations.tableSectionHeightLarge
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return queuedRequests.count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if !queuedRequests.isEmpty {
            return "Downloading"
        } else {
            return "No active downloads"
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: SongTableCell = dequeueCell(for: tableView, at: indexPath)
        if indexPath.row < queuedRequests.count {
            cell.display(song: queuedRequests[indexPath.row].element, rootView: self)
        }
        cell.isUserTouchInteractionAllowed = false

        return cell
    }

    func downloadManager(_ downloadManager: DownloadManager, updatedRequest: DownloadRequest<Song>, updateReason: SongDownloadRequestEvent) {
        switch(updateReason) {
        case .updateProgress:
            let arrayIndices = queuedRequests.allIndices(of: updatedRequest)
            for index in arrayIndices {
                if let cell = self.tableView.cellForRow(at: IndexPath(row: index, section: Section.queuedRequests.rawValue)) as? SongTableCell {
                    cell.display(song: updatedRequest.element, rootView: self, download: updatedRequest.download)
                }
            }
        case .added:
            tableView.beginUpdates()
            var indexPath = IndexPath()
            if updatedRequest.priority == .high {
                queuedRequests.insert(updatedRequest, at: 0)
                indexPath = IndexPath(row: 0, section: Section.queuedRequests.rawValue)
            } else {
                queuedRequests.append(updatedRequest)
                indexPath = IndexPath(row: queuedRequests.count-1, section: Section.queuedRequests.rawValue)
            }
            tableView.insertRows(at: [indexPath], with: .automatic)
            tableView.endUpdates()
        case .removed:
            tableView.beginUpdates()
            let arrayIndices = queuedRequests.allIndices(of: updatedRequest)
            for index in arrayIndices.reversed() {
                queuedRequests.remove(at: index)
                let indexPath = IndexPath(row: index, section: Section.queuedRequests.rawValue)
                tableView.deleteRows(at: [indexPath], with: .automatic)
            }
            tableView.endUpdates()
        case .started:
            break
        case .finished:
            let arrayIndices = queuedRequests.allIndices(of: updatedRequest)
            for index in arrayIndices {
                if let cell = self.tableView.cellForRow(at: IndexPath(row: index, section: Section.queuedRequests.rawValue)) as? SongTableCell {
                    cell.display(song: updatedRequest.element, rootView: self)
                }
            }
        }
    }

}
