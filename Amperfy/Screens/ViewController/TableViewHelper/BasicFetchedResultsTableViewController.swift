//
//  BasicFetchedResultsTableViewController.swift
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

class BasicFetchedResultsTableViewController<ResultType>: BasicTableViewController
  where ResultType: NSFetchRequestResult {
  var isIndexTitelsHidden = false

  private var singleFetchController: BasicFetchedResultsController<ResultType>?
  var singleFetchedResultsController: BasicFetchedResultsController<ResultType>? {
    set { singleFetchController = newValue }
    get { singleFetchController }
  }

  override func numberOfSections(in tableView: UITableView) -> Int {
    singleFetchController?.numberOfSections ?? 0
  }

  override func tableView(
    _ tableView: UITableView,
    titleForHeaderInSection section: Int
  )
    -> String? {
    singleFetchController?.titleForHeader(inSection: section)
  }

  // This fixes a bug where macOS is missing a separator line at the end of a section.
  // This looks ugly in view controller, such as the SongVC, where there is no clear distinction between sections.
  // iOS only removes a separator line at the end of a section if a footer view exists.
  // macOS always removes the separator, no matter if there is a footer or not. Therefore, we manually add a separator on macOS.
  #if targetEnvironment(macCatalyst)
    override func tableView(
      _ tableView: UITableView,
      viewForFooterInSection section: Int
    )
      -> UIView? {
      guard tableView.separatorStyle == .singleLine else {
        return nil
      }

      let container = UIView()
      container.backgroundColor = .clear

      let separator = UIView()
      separator.backgroundColor = tableView.separatorColor ?? .separator
      separator.translatesAutoresizingMaskIntoConstraints = false
      container.addSubview(separator)

      let leadingX = tableView.separatorInset.left
      let trailingX = tableView.separatorInset.right

      NSLayoutConstraint.activate([
        separator.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: leadingX),
        separator.trailingAnchor.constraint(
          equalTo: container.trailingAnchor,
          constant: -trailingX
        ),
        separator.topAnchor.constraint(equalTo: container.topAnchor),
        separator.bottomAnchor.constraint(equalTo: container.bottomAnchor),
      ])

      return container
    }

    override func tableView(
      _ tableView: UITableView,
      heightForFooterInSection section: Int
    )
      -> CGFloat {
      guard tableView.separatorStyle == .singleLine else {
        return 0.0
      }
      return 0.5
    }
  #endif

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    singleFetchController?.numberOfRows(inSection: section) ?? 0
  }

  override func sectionIndexTitles(for tableView: UITableView) -> [String]? {
    isIndexTitelsHidden ? nil : singleFetchController?.sectionIndexTitles
  }

  override func tableView(
    _ tableView: UITableView,
    sectionForSectionIndexTitle title: String,
    at index: Int
  )
    -> Int {
    singleFetchController?.section(forSectionIndexTitle: title, at: index) ?? 0
  }
}
