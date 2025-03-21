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

  #if targetEnvironment(macCatalyst)
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let container = UIView()
        let x = tableView.separatorInset.left
        let width = tableView.frame.width - tableView.separatorInset.left - tableView.separatorInset.right
        let separator = UIView(frame: CGRect(x: x, y: 0, width: width, height: 0.5))
        separator.backgroundColor = .separator

        container.addSubview(separator)
        return container
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
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
