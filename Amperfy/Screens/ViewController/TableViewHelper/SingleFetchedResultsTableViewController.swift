//
//  SingleFetchedResultsTableViewController.swift
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

class SingleFetchedResultsTableViewController<ResultType>: BasicFetchedResultsTableViewController<
  ResultType
>
  where ResultType: NSFetchRequestResult {
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

  override func viewIsAppearing(_ animated: Bool) {
    super.viewIsAppearing(animated)
    singleFetchedResultsController?.delegate = resultUpdateHandler
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    singleFetchedResultsController?.delegate = nil
  }
}
