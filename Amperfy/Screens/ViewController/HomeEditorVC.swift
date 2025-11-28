//
//  HomeEditorVC.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 24.11.25.
//  Copyright (c) 2025 Maximilian Bauer. All rights reserved.
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

final class HomeEditorVC: UITableViewController {
  private var sections: [HomeSection]
  private var visibility: [HomeSection: Bool]
  private let onDone: ([HomeSection]) -> ()

  init(current: [HomeSection], onDone: @escaping ([HomeSection]) -> ()) {
    self.sections = current
    self.onDone = onDone
    var vis: [HomeSection: Bool] = [:]
    // Default all known sections to hidden=false, then mark visible ones
    for s in HomeSection.allCases { vis[s] = false }
    for s in current { vis[s] = true }
    self.visibility = vis
    super.init(style: .insetGrouped)
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func viewDidLoad() {
    super.viewDidLoad()
    navigationItem.rightBarButtonItems = [
      UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneTapped)),
    ]
    tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
    title = "Home Preferences"
    isEditing = true
  }

  @objc
  private func doneTapped() {
    // Persist order of only visible sections
    let newOrder = sections.filter { visibility[$0] == true }
    onDone(newOrder)
    dismiss(animated: true)
  }

  // MARK: - Table

  override func numberOfSections(in tableView: UITableView) -> Int { 2 }

  override func tableView(
    _ tableView: UITableView,
    titleForHeaderInSection section: Int
  )
    -> String? {
    section == 0 ? "Visible" : "Hidden"
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    if section == 0 {
      return sections.filter { visibility[$0] == true }.count
    } else {
      return HomeSection.allCases.filter { visibility[$0] != true }.count
    }
  }

  private func sectionFor(indexPath: IndexPath) -> HomeSection {
    if indexPath.section == 0 {
      return sections.filter { visibility[$0] == true }[indexPath.row]
    } else {
      return HomeSection.allCases.filter { visibility[$0] != true }[indexPath.row]
    }
  }

  override func tableView(
    _ tableView: UITableView,
    cellForRowAt indexPath: IndexPath
  )
    -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
    let s = sectionFor(indexPath: indexPath)
    cell.textLabel?.text = s.title
    cell.accessoryType = .none
    return cell
  }

  override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
    true
  }

  override func tableView(
    _ tableView: UITableView,
    moveRowAt sourceIndexPath: IndexPath,
    to destinationIndexPath: IndexPath
  ) {
    var visible = sections.filter { visibility[$0] == true }
    var hidden = HomeSection.allCases.filter { visibility[$0] != true }

    // same as select
    if sourceIndexPath.section != destinationIndexPath.section {
      if destinationIndexPath.section == 0 {
        // show
        visibility[hidden[sourceIndexPath.row]] = true
        let moved = hidden.remove(at: sourceIndexPath.row)
        visible.insert(moved, at: destinationIndexPath.row)
      } else {
        // hide
        visibility[visible[sourceIndexPath.row]] = false
        let moved = visible.remove(at: sourceIndexPath.row)
        hidden.insert(moved, at: destinationIndexPath.row)
      }
    } else if sourceIndexPath.section == destinationIndexPath.section,
              sourceIndexPath.section == 1 {
      // Reorder within hidden
      let moved = hidden.remove(at: sourceIndexPath.row)
      hidden.insert(moved, at: destinationIndexPath.row)
    } else {
      // Reorder within visible
      let moved = visible.remove(at: sourceIndexPath.row)
      visible.insert(moved, at: destinationIndexPath.row)
    }
    // Rebuild sections array: keep order of visible first, then append existing hidden order
    sections = visible + hidden
  }

  override func tableView(
    _ tableView: UITableView,
    editingStyleForRowAt indexPath: IndexPath
  )
    -> UITableViewCell.EditingStyle {
    .none
  }

  override func tableView(
    _ tableView: UITableView,
    shouldIndentWhileEditingRowAt indexPath: IndexPath
  )
    -> Bool { false }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    let s = sectionFor(indexPath: indexPath)
    // Toggle visibility
    visibility[s] = !(visibility[s] ?? false)
    updateSections()

    tableView.performBatchUpdates({
      tableView.reloadSections(IndexSet(integer: 0), with: .automatic)
      tableView.reloadSections(IndexSet(integer: 1), with: .automatic)
    })
  }

  func updateSections() {
    let visible = sections.filter { visibility[$0] == true }
    let hidden = HomeSection.allCases.filter { visibility[$0] != true }
    sections = visible + hidden
  }
}
