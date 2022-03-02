import Foundation
import UIKit

class DownloadsVC: SingleFetchedResultsTableViewController<DownloadMO> {
    
    private var fetchedResultsController: DownloadsFetchedResultsController!
    private var actionButton: UIBarButtonItem!
    private var downloadManager: DownloadManageable!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate.userStatistics.visited(.downloads)
        downloadManager = appDelegate.playableDownloadManager
        
        fetchedResultsController = DownloadsFetchedResultsController(managedObjectContext: appDelegate.persistentStorage.context, isGroupedInAlphabeticSections: false)
        singleFetchedResultsController = fetchedResultsController
        
        tableView.register(nibName: PlayableTableCell.typeName)
        tableView.rowHeight = PlayableTableCell.rowHeight
        
        actionButton = UIBarButtonItem(image: UIImage.ellipsis, style: .plain, target: self, action: #selector(performActionButtonOperation))
        navigationItem.rightBarButtonItem = actionButton
    }
    
    
    @objc private func performActionButtonOperation() {
        let alert = UIAlertController(title: "Downloads", message: nil, preferredStyle: .actionSheet)
        let activeDownloadIndex = fetchedResultsController.fetchedObjects?.compactMap{ Download(managedObject: $0) }.enumerated().first(where: {$1.isDownloading})
        if let activeDownloadIndex = activeDownloadIndex {
            alert.addAction(UIAlertAction(title: "Scroll to active downloads", style: .default, handler: { _ in
                self.tableView.scrollToRow(at: IndexPath(row: activeDownloadIndex.offset, section: 0), at: .top, animated: true)
            }))
        }
        alert.addAction(UIAlertAction(title: "Clear finished downloads", style: .default, handler: { _ in
            self.downloadManager.clearFinishedDownloads()
        }))
        alert.addAction(UIAlertAction(title: "Retry failed downloads", style: .default, handler: { _ in
            self.downloadManager.resetFailedDownloads()
        }))
        alert.addAction(UIAlertAction(title: "Cancel all downloads", style: .default, handler: { _ in
            self.downloadManager.cancelDownloads()
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.pruneNegativeWidthConstraintsToAvoidFalseConstraintWarnings()
        alert.setOptionsForIPadToDisplayPopupCentricIn(view: self.view)
        present(alert, animated: true, completion: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        fetchedResultsController.fetch()
    }
    
    func convertCellViewToPlayContext(cell: UITableViewCell) -> PlayContext? {
        guard let indexPath = tableView.indexPath(for: cell) else { return nil }
        let downdload = fetchedResultsController.getWrappedEntity(at: indexPath)
        guard let playable = downdload.element as? AbstractPlayable else { return nil }
        return PlayContext(containable: playable)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: PlayableTableCell = dequeueCell(for: tableView, at: indexPath)
        let download = fetchedResultsController.getWrappedEntity(at: indexPath)
        if let playable = download.element as? AbstractPlayable {
            cell.display(playable: playable, playContextCb: convertCellViewToPlayContext, rootView: self, download: download)
        }
        return cell
    }
    
}
