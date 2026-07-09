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

  private var savedQueues: [SavedQueue] = []

  init() {
    super.init(style: .plain)
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func viewDidLoad() {
    super.viewDidLoad()
    setNavBarTitle(title: "Saved Queues")
    tableView.backgroundColor = .backgroundColor
    tableView.sectionFooterHeight = 0.0
    tableView.estimatedSectionFooterHeight = 0.0
    tableView.sectionHeaderHeight = 0.0
    tableView.estimatedSectionHeaderHeight = 0.0

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
    savedQueues = appDelegate.savedQueues.list()
    tableView.reloadData()
    updateContentUnavailable()
  }

  private func updateContentUnavailable() {
    if savedQueues.isEmpty {
      var config = UIContentUnavailableConfiguration.empty()
      config.image = .savedQueues
      config.text = "No Saved Queues"
      config.secondaryText =
        "Queues are saved automatically when you start a new one. Tap a queue to resume it."
      contentUnavailableConfiguration = config
    } else {
      contentUnavailableConfiguration = nil
    }
  }

  private func resume(_ savedQueue: SavedQueue) {
    Task { @MainActor in
      await appDelegate.player.restore(savedQueue: savedQueue)
    }
  }

  private func showDetail(for savedQueue: SavedQueue) {
    let detailVC = SavedQueueDetailVC(savedQueue: savedQueue)
    navigationController?.pushViewController(detailVC, animated: true)
  }

  private func promptRename(_ savedQueue: SavedQueue) {
    let alert = UIAlertController(title: "Rename Queue", message: nil, preferredStyle: .alert)
    alert.addTextField { tf in tf.text = savedQueue.name }
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    alert.addAction(UIAlertAction(title: "Rename", style: .default) { _ in
      guard let name = alert.textFields?.first?.text else { return }
      self.appDelegate.savedQueues.rename(savedQueue, to: name)
      // reload() triggers via .savedQueueListChanged notification
    })
    present(alert, animated: true)
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
    let formatter = RelativeDateTimeFormatter()
    let dateString = formatter.localizedString(for: queue.lastUsedAt, relativeTo: Date())
    // Match the playlist cell typography (17pt name, 14pt secondary info),
    // just without the artwork.
    var content = cell.defaultContentConfiguration()
    content.text = queue.name
    content.textProperties.font = .systemFont(ofSize: 17)
    content.textProperties.color = .label
    content.secondaryText = "\(queue.songCount) Songs · \(dateString)"
    content.secondaryTextProperties.font = .systemFont(ofSize: 14)
    content.secondaryTextProperties.color = .secondaryLabel
    content.textToSecondaryTextVerticalPadding = 2.0
    cell.contentConfiguration = content
    cell.backgroundColor = .systemBackground
    // Tapping the row resumes the queue; the detail button opens the song
    // list.
    cell.accessoryType = .detailButton
    return cell
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    resume(savedQueues[indexPath.row])
    tableView.deselectRow(at: indexPath, animated: true)
  }

  override func tableView(
    _ tableView: UITableView,
    accessoryButtonTappedForRowWith indexPath: IndexPath
  ) {
    showDetail(for: savedQueues[indexPath.row])
  }

  override func tableView(
    _ tableView: UITableView,
    contextMenuConfigurationForRowAt indexPath: IndexPath,
    point: CGPoint
  )
    -> UIContextMenuConfiguration? {
    let queue = savedQueues[indexPath.row]
    return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
      let resume = UIAction(title: "Resume", image: UIImage(systemName: "play")) { _ in
        self.resume(queue)
      }
      let showSongs = UIAction(
        title: "Show Songs",
        image: UIImage(systemName: "music.note.list")
      ) { _ in
        self.showDetail(for: queue)
      }
      let rename = UIAction(title: "Rename", image: UIImage(systemName: "pencil")) { _ in
        self.promptRename(queue)
      }
      let delete = UIAction(
        title: "Delete",
        image: UIImage(systemName: "trash"),
        attributes: .destructive
      ) { _ in
        self.appDelegate.savedQueues.delete(queue)
      }
      return UIMenu(children: [resume, showSongs, rename, delete])
    }
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
