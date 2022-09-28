//
//  DownloadsVC.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 09.03.19.
//  Copyright (c) 2019 Maximilian Bauer. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation
import UIKit
import AmperfyKit

class DownloadsVC: SingleFetchedResultsTableViewController<DownloadMO> {
    
    private var fetchedResultsController: DownloadsFetchedResultsController!
    private var actionButton: UIBarButtonItem!
    private var downloadManager: DownloadManageable!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate.userStatistics.visited(.downloads)
        downloadManager = appDelegate.playableDownloadManager
        
        fetchedResultsController = DownloadsFetchedResultsController(coreDataCompanion: appDelegate.storage.main, isGroupedInAlphabeticSections: false)
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
        alert.popoverPresentationController?.barButtonItem = actionButton
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
