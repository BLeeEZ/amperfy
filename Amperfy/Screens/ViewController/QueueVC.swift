//
//  QueueVC.swift
//  Amperfy
//
//  Created by David Klopp on 31.08.24.
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
import Foundation
import UIKit

// Found by trial and error
let scrollbarZPosition: CGFloat = 1000

// MARK: - QueueVC

class QueueVC: UIViewController {
  var contextPrevQueueSectionHeader: ContextQueuePrevSectionHeader?
  var userQueueSectionHeader: UserQueueSectionHeader?
  var contextNextQueueSectionHeader: ContextQueueNextSectionHeader?
  lazy var clearEmptySectionFooter = {
    let view = UIView()
    view.backgroundColor = .clear
    view.isHidden = true
    return view
  }()

  override var title: String? {
    get { "Queue" }
    set {}
  }

  var player: PlayerFacade {
    appDelegate.player
  }

  var tableView: UITableView?

  var mainViewController: UIViewController? {
    AppDelegate.mainWindowHostVC as? UIViewController
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    let tableView = UITableView(frame: .zero, style: .plain)
    view.addSubview(tableView)

    tableView.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
      tableView.topAnchor.constraint(equalTo: view.topAnchor),
      tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
    ])

    self.tableView = tableView
    setupTableView()

    tableView.delegate = self
    tableView.dataSource = self
    tableView.dragDelegate = self
    tableView.dropDelegate = self
    tableView.dragInteractionEnabled = true

    if let sectionView = ViewCreator<ContextQueuePrevSectionHeader>
      .createFromNib(withinFixedFrame: CGRect(
        x: 0,
        y: 0,
        width: view.bounds.size.width,
        height: ContextQueuePrevSectionHeader.frameHeight
      )) {
      sectionView.setBackgroundBlur(style: .prominent)
      sectionView.backgroundColor = .clear
      // Workaround for an OS bug, where the cell is suddenly rendered above the section header after reorder
      sectionView.layer.zPosition = scrollbarZPosition - 1
      contextPrevQueueSectionHeader = sectionView
      contextPrevQueueSectionHeader?.display(name: "Previous")
    }
    if let sectionView = ViewCreator<UserQueueSectionHeader>
      .createFromNib(withinFixedFrame: CGRect(
        x: 0,
        y: 0,
        width: view.bounds.size.width,
        height: UserQueueSectionHeader.frameHeight
      )) {
      sectionView.setBackgroundBlur(style: .prominent)
      sectionView.backgroundColor = .clear
      sectionView.layer.zPosition = scrollbarZPosition - 1
      userQueueSectionHeader = sectionView
      userQueueSectionHeader?.display(name: "Next from Queue", buttonPressAction: clearUserQueue)
    }
    if let sectionView = ViewCreator<ContextQueueNextSectionHeader>
      .createFromNib(withinFixedFrame: CGRect(
        x: 0,
        y: 0,
        width: view.bounds.size.width,
        height: ContextQueueNextSectionHeader.frameHeight
      )) {
      sectionView.setBackgroundBlur(style: .prominent)
      sectionView.backgroundColor = .clear
      sectionView.layer.zPosition = scrollbarZPosition - 1
      contextNextQueueSectionHeader = sectionView
    }

    // hard top border -> other glass effect is to big and covers top sidebar elements
    self.tableView!.topEdgeEffect.style = .hard
    navigationController?.navigationBar.isTranslucent = false

    player.addNotifier(notifier: self)
    refresh()
  }

  override var traitCollection: UITraitCollection {
    super.traitCollection.modifyingTraits { traits in
      traits.horizontalSizeClass = .compact
      traits.verticalSizeClass = .compact
    }
  }
}

// MARK: UITableViewDelegate, UITableViewDataSource

extension QueueVC: UITableViewDelegate, UITableViewDataSource {
  func setupTableView() {
    tableView?.register(nibName: PlayableTableCell.typeName)
    tableView?.rowHeight = PlayableTableCell.rowHeight
    tableView?.estimatedRowHeight = PlayableTableCell.rowHeight
    tableView?.backgroundColor = .clear
    tableView?.sectionHeaderTopPadding = 0.0
  }

  func refreshUserQueueSectionHeader() {
    if player.userQueueCount == 0 {
      userQueueSectionHeader?.hide()
    } else {
      userQueueSectionHeader?.display(
        name: PlayerQueueType.user.description,
        buttonPressAction: clearUserQueue
      )
    }
  }

  func refreshContextQueueSectionHeader() {
    contextNextQueueSectionHeader?.refresh()
  }

  func clearUserQueue() {
    guard player.userQueueCount > 0 else { return }
    tableView?.beginUpdates()
    var indexPaths = [IndexPath]()
    for i in 0 ... player.userQueueCount - 1 {
      indexPaths.append(IndexPath(row: i, section: PlayerSectionCategory.userQueue.rawValue))
    }
    tableView?.deleteRows(at: indexPaths, with: .fade)
    player.clearUserQueue()
    tableView?.endUpdates()
    refreshUserQueueSectionHeader()
  }

  func convertCellViewToPlayerIndex(cell: PlayableTableCell) -> PlayerIndex? {
    guard let indexPath = tableView?.indexPath(for: cell),
          let playerIndex = PlayerIndex.create(from: indexPath) else { return nil }
    return playerIndex
  }

  func numberOfSections(in tableView: UITableView) -> Int {
    PlayerSectionCategory.allCases.count
  }

  func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    nil
  }

  func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    let sectionCategors = PlayerSectionCategory(rawValue: section)
    switch sectionCategors {
    case .contextPrev:
      return contextPrevQueueSectionHeader
    case .userQueue:
      refreshUserQueueSectionHeader()
      return userQueueSectionHeader
    case .contextNext:
      return contextNextQueueSectionHeader
    default:
      return nil
    }
  }

  func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    switch PlayerSectionCategory(rawValue: section) {
    case .contextPrev:
      return ContextQueuePrevSectionHeader.frameHeight
    case .userQueue:
      if player.userQueueCount == 0 {
        return CGFloat.leastNormalMagnitude
      } else {
        return UserQueueSectionHeader.frameHeight
      }
    case .contextNext:
      return ContextQueueNextSectionHeader.frameHeight
    default:
      return 0.0
    }
  }

  func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
    switch PlayerSectionCategory(rawValue: section) {
    case .contextNext, .contextPrev:
      return clearEmptySectionFooter
    default:
      return nil
    }
  }

  func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
    0
  }

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    switch PlayerSectionCategory(rawValue: section) {
    case .contextPrev: return player.prevQueueCount
    case .userQueue: return player.userQueueCount
    case .contextNext: return player.nextQueueCount
    default: return 0
    }
  }

  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    let sectionCategors = PlayerSectionCategory(rawValue: indexPath.section)
    switch sectionCategors {
    case .contextNext, .contextPrev, .none, .userQueue:
      return PlayableTableCell.rowHeight
    default:
      return 0
    }
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    guard let tableView = self.tableView else {
      return UITableViewCell(frame: .zero)
    }
    switch PlayerSectionCategory(rawValue: indexPath.section) {
    case .contextNext, .contextPrev, .userQueue:
      let cell: PlayableTableCell = tableView.dequeueCell(for: tableView, at: indexPath)

      guard let playerIndex = PlayerIndex.create(from: indexPath),
            let playable = player.getPlayable(at: playerIndex)
      else { return cell }
      cell.display(
        playable: playable,
        playContextCb: { _ in PlayContext() },
        rootView: self,
        playerIndexCb: convertCellViewToPlayerIndex
      )
      cell.backgroundColor = .clear
      return cell
    default:
      return UITableViewCell()
    }
  }

  // Override to allow editing only for certain rows
  func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    // don't allow to delete via swipe
    false
  }

  // Override to support editing the table view.
  func tableView(
    _ tableView: UITableView,
    commit editingStyle: UITableViewCell.EditingStyle,
    forRowAt indexPath: IndexPath
  ) {
    if editingStyle == .delete {
      guard let playerIndex = PlayerIndex.create(from: indexPath) else { return }
      player.removePlayable(at: playerIndex)
      tableView.deleteRows(at: [indexPath], with: .fade)
      if PlayerSectionCategory(rawValue: indexPath.section) == .userQueue {
        refreshUserQueueSectionHeader()
      }
    }
  }

  // Override to support rearranging the table view.
  func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {
    guard fromIndexPath != to,
          let fromPlayerIndex = PlayerIndex.create(from: fromIndexPath),
          let toPlayerIndex = PlayerIndex.create(from: to)
    else { return }
    player.movePlayable(from: fromPlayerIndex, to: toPlayerIndex)
    if PlayerSectionCategory(rawValue: fromIndexPath.section) == .userQueue ||
      PlayerSectionCategory(rawValue: to.section) == .userQueue {
      refreshUserQueueSectionHeader()
    }
  }

  // Override to deny movment of rows to specific sections
  func tableView(
    _ tableView: UITableView,
    targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath,
    toProposedIndexPath targetIndexPath: IndexPath
  )
    -> IndexPath {
    targetIndexPath
  }

  // Override to support conditional rearranging of the table view.
  func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
    // Return false if you do not want the item to be re-orderable.
    switch PlayerSectionCategory(rawValue: indexPath.section) {
    case .contextNext, .contextPrev, .userQueue: return true
    default: return false
    }
  }

  /// long press on cell animation (cell content gets smaller)
  private func makeTargetedPreview(
    for configuration: UIContextMenuConfiguration,
    willBeShown: Bool
  )
    -> UITargetedPreview? {
    guard let identifier = configuration.identifier as? String,
          let tvPreviewInfo = TableViewPreviewInfo.create(fromIdentifier: identifier),
          let indexPath = tvPreviewInfo.indexPath,
          let cell = tableView?.cellForRow(at: indexPath) as? PlayableTableCell
    else { return nil }

    let parameters = UIPreviewParameters()
    parameters.backgroundColor = .clear
    return UITargetedPreview(view: cell, parameters: parameters)
  }

  func tableView(
    _ tableView: UITableView,
    previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration
  )
    -> UITargetedPreview? {
    makeTargetedPreview(for: configuration, willBeShown: true)
  }

  func tableView(
    _ tableView: UITableView,
    previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration
  )
    -> UITargetedPreview? {
    makeTargetedPreview(for: configuration, willBeShown: false)
  }

  func tableView(
    _ tableView: UITableView,
    contextMenuConfigurationForRowAt indexPath: IndexPath,
    point: CGPoint
  )
    -> UIContextMenuConfiguration? {
    guard let playerIndex = PlayerIndex.create(from: indexPath),
          let containable = player.getPlayable(at: playerIndex)
    else { return nil }
    let identifier = NSString(string: TableViewPreviewInfo(
      playableContainerIdentifier: containable.containerIdentifier,
      indexPath: indexPath
    ).asJSONString())
    return UIContextMenuConfiguration(identifier: identifier, previewProvider: {
      let vc = EntityPreviewVC()
      vc.display(container: containable, on: self)
      return vc
    }) { suggestedActions in
      guard let mainController = self.mainViewController else {
        return UIMenu()
      }
      return EntityPreviewActionBuilder(container: containable, on: mainController).createMenu()
    }
  }

  func tableView(
    _ tableView: UITableView,
    willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration,
    animator: UIContextMenuInteractionCommitAnimating
  ) {
    animator.addCompletion {
      if let identifier = configuration.identifier as? String,
         let tvPreviewInfo = TableViewPreviewInfo.create(fromIdentifier: identifier),
         let containerIdentifier = tvPreviewInfo.playableContainerIdentifier,
         let container = self.appDelegate.storage.main.library
         .getContainer(identifier: containerIdentifier),
         let mainController = self.mainViewController {
        EntityPreviewActionBuilder(container: container, on: mainController)
          .performPreviewTransition()
      }
    }
  }
}

// MARK: UITableViewDragDelegate

extension QueueVC: UITableViewDragDelegate {
  func tableView(
    _ tableView: UITableView,
    itemsForBeginning session: UIDragSession,
    at indexPath: IndexPath
  )
    -> [UIDragItem] {
    []
  }

  func tableView(
    _ tableView: UITableView,
    dragPreviewParametersForRowAt indexPath: IndexPath
  )
    -> UIDragPreviewParameters? {
    let parameter = UIDragPreviewParameters()
    parameter.backgroundColor = .clear
    return parameter
  }
}

// MARK: UITableViewDropDelegate

extension QueueVC: UITableViewDropDelegate {
  func tableView(_ tableView: UITableView, canHandle session: UIDropSession) -> Bool {
    false
  }

  // Local drags with one item go through the existing tableView(_:moveRowAt:to:) method on the data source
  func tableView(
    _ tableView: UITableView,
    performDropWith coordinator: UITableViewDropCoordinator
  ) {}

  func tableView(_ tableView: UITableView, dropSessionDidEnd session: UIDropSession) {}

  func tableView(
    _ tableView: UITableView,
    dropPreviewParametersForRowAt indexPath: IndexPath
  )
    -> UIDragPreviewParameters? {
    let parameter = UIDragPreviewParameters()
    parameter.backgroundColor = .clear
    return parameter
  }
}

// MARK: MusicPlayable

extension QueueVC: MusicPlayable {
  func refresh() {
    refreshContextQueueSectionHeader()
    refreshUserQueueSectionHeader()
  }

  func reloadData() {
    tableView?.reloadData()
  }

  func didStartPlaying() {
    reloadData()
    refresh()
  }

  func didStopPlaying() {
    reloadData()
    refresh()
  }

  func didPlaylistChange() {
    reloadData()
    refresh()
  }

  func didShuffleChange() {
    reloadData()
    refresh()
  }

  func didRepeatChange() {
    reloadData()
    refresh()
  }

  func didStartPlayingFromBeginning() {}
  func didPause() {}
  func didElapsedTimeChange() {}
  func didArtworkChange() {}
  func didPlaybackRateChange() {}
}
