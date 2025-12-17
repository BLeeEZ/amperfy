//
//  MultiSourceTableViewController.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 23.02.24.
//  Copyright (c) 2024 Maximilian Bauer. All rights reserved.
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

import AmperfyKit
import CoreData
import UIKit

// MARK: - MultiSourceTableViewController

class MultiSourceTableViewController: BasicTableViewController {
  public var resultUpdateHandler: FetchUpdatePerObjectHandler?
  let account: Account

  init(style: UITableView.Style, account: Account) {
    self.account = account
    super.init(style: style)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    resultUpdateHandler = FetchUpdatePerObjectHandler(tableView: tableView)
  }
}

extension MultiSourceTableViewController: @preconcurrency NSFetchedResultsControllerDelegate {
  public func controllerWillChangeContent(
    _ controller: NSFetchedResultsController<NSFetchRequestResult>
  ) {
    MainActor.assumeIsolated {
      resultUpdateHandler?.controllerWillChangeContent(controller)
    }
  }

  public func controllerDidChangeContent(
    _ controller: NSFetchedResultsController<NSFetchRequestResult>
  ) {
    MainActor.assumeIsolated {
      resultUpdateHandler?.controllerDidChangeContent(controller)
    }
  }

  public func controller(
    _ controller: NSFetchedResultsController<NSFetchRequestResult>,
    didChange anObject: Any,
    at indexPath: IndexPath?,
    for type: NSFetchedResultsChangeType,
    newIndexPath: IndexPath?
  ) {
    MainActor.assumeIsolated {
      resultUpdateHandler?.controller(
        controller,
        didChange: anObject,
        at: indexPath,
        for: type,
        newIndexPath: newIndexPath
      )
    }
  }

  public func controller(
    _ controller: NSFetchedResultsController<NSFetchRequestResult>,
    didChange sectionInfo: NSFetchedResultsSectionInfo,
    atSectionIndex sectionIndex: Int,
    for type: NSFetchedResultsChangeType
  ) {
    MainActor.assumeIsolated {
      resultUpdateHandler?.controller(
        controller,
        didChange: sectionInfo,
        atSectionIndex: sectionIndex,
        for: type
      )
    }
  }
}
