//
//  SavedQueuesVC.swift
//  Amperfy
//
//  Created by Amperfy Contributors on 09.06.26.
//  Copyright (c) 2026 Maximilian Bauer. All rights reserved.
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
import UIKit

class SavedQueuesVC: BasicTableViewController {
  override var sceneTitle: String? { "Saved Queues" }

  private let account: Account
  private var savedQueues: [SavedQueue] = []

  init(account: Account) {
    self.account = account
    super.init(style: .grouped)
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func viewDidLoad() {
    super.viewDidLoad()
    setNavBarTitle(title: "Saved Queues")
    tableView.backgroundColor = .backgroundColor

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(reload),
      name: .savedQueueListChanged,
      object: nil
    )
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.navigationBar.prefersLargeTitles = true
    reload()
  }

  override func viewIsAppearing(_ animated: Bool) {
    super.viewIsAppearing(animated)
    extendSafeAreaToAccountForMiniPlayer()
  }

  @objc
  private func reload() {
    savedQueues = appDelegate.savedQueues.list(forAccount: account)
    tableView.reloadData()
    updateContentUnavailable()
  }

  private func updateContentUnavailable() {
    if savedQueues.isEmpty {
      var config = UIContentUnavailableConfiguration.empty()
      config.image = .savedQueues
      config.text = "No Saved Queues"
      config.secondaryText = "Queues are saved automatically when you start a new one."
      contentUnavailableConfiguration = config
    } else {
      contentUnavailableConfiguration = nil
    }
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    savedQueues.count
  }

  override func tableView(
    _ tableView: UITableView,
    cellForRowAt indexPath: IndexPath
  )
    -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "SavedQueueCell")
      ?? UITableViewCell(style: .subtitle, reuseIdentifier: "SavedQueueCell")
    let queue = savedQueues[indexPath.row]
    cell.textLabel?.text = queue.name
    let formatter = RelativeDateTimeFormatter()
    let dateString = formatter.localizedString(for: queue.createdAt, relativeTo: Date())
    cell.detailTextLabel?.text = "\(queue.songCount) songs · \(dateString)"
    cell.accessoryType = .disclosureIndicator
    return cell
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let queue = savedQueues[indexPath.row]
    let detailVC = SavedQueueDetailVC(account: account, savedQueue: queue)
    navigationController?.pushViewController(detailVC, animated: true)
    tableView.deselectRow(at: indexPath, animated: true)
  }

  override func tableView(
    _ tableView: UITableView,
    commit editingStyle: UITableViewCell.EditingStyle,
    forRowAt indexPath: IndexPath
  ) {
    guard editingStyle == .delete else { return }
    let queue = savedQueues[indexPath.row]
    appDelegate.savedQueues.delete(queue)
    // reload() triggers via .savedQueueListChanged notification
  }
}
