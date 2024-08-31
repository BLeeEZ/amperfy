//
//  QueueVC.swift
//  Amperfy
//
//  Created by David Klopp on 31.08.24.
//  Copyright © 2024 Maximilian Bauer. All rights reserved.
//

import Foundation
import UIKit
import AmperfyKit

#if targetEnvironment(macCatalyst)

class QueueVC: SliderOverItemVC {
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
        get { return "Queue" }
        set {}
    }

    var player: PlayerFacade {
        return self.appDelegate.player
    }

    var tableView: UITableView?

    override func viewDidLoad() {
        super.viewDidLoad()

        let tableView =  UITableView(frame: .zero, style: .plain)
        self.view.addSubview(tableView)

        tableView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: self.view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor)
        ])

        self.tableView = tableView
        self.setupTableView()

        tableView.delegate = self
        tableView.dataSource = self
        tableView.dragDelegate = self
        tableView.dropDelegate = self
        tableView.dragInteractionEnabled = true

        if let sectionView = ViewCreator<ContextQueuePrevSectionHeader>.createFromNib(withinFixedFrame: CGRect(x: 0, y: 0, width: view.bounds.size.width, height: ContextQueuePrevSectionHeader.frameHeight)) {
            sectionView.setBackgroundBlur(style: .prominent)
            sectionView.backgroundColor = .clear
            contextPrevQueueSectionHeader = sectionView
            contextPrevQueueSectionHeader?.display(name: "Previous")
        }
        if let sectionView = ViewCreator<UserQueueSectionHeader>.createFromNib(withinFixedFrame: CGRect(x: 0, y: 0, width: view.bounds.size.width, height: UserQueueSectionHeader.frameHeight)) {
            sectionView.setBackgroundBlur(style: .prominent)
            sectionView.backgroundColor = .clear
            userQueueSectionHeader = sectionView
            userQueueSectionHeader?.display(name: "Next from Queue", buttonPressAction: clearUserQueue)
        }
        if let sectionView = ViewCreator<ContextQueueNextSectionHeader>.createFromNib(withinFixedFrame: CGRect(x: 0, y: 0, width: view.bounds.size.width, height: ContextQueueNextSectionHeader.frameHeight)) {
            sectionView.setBackgroundBlur(style: .prominent)
            sectionView.backgroundColor = .clear
            contextNextQueueSectionHeader = sectionView
        }

        self.player.addNotifier(notifier: self)
        self.refresh()
    }

    override var traitCollection: UITraitCollection {
        let compactHorizontalCollection = UITraitCollection(horizontalSizeClass: .compact)
        let compactVerticalCollection = UITraitCollection(verticalSizeClass: .compact)
        let newCollection = UITraitCollection(traitsFrom: [
            super.traitCollection, compactHorizontalCollection, compactVerticalCollection
        ])
        return newCollection
    }
}

extension QueueVC: UITableViewDelegate, UITableViewDataSource {
    func setupTableView() {
        self.tableView?.register(nibName: PlayableTableCell.typeName)
        self.tableView?.rowHeight = PlayableTableCell.rowHeight
        self.tableView?.estimatedRowHeight = PlayableTableCell.rowHeight
        self.tableView?.backgroundColor = .clear
        self.tableView?.sectionHeaderTopPadding = 0.0
    }

    func refreshUserQueueSectionHeader() {
        if self.player.userQueue.isEmpty {
            self.userQueueSectionHeader?.hide()
        } else {
            self.userQueueSectionHeader?.display(name: PlayerQueueType.user.description, buttonPressAction: self.clearUserQueue)
        }
    }

    func refreshContextQueueSectionHeader() {
        self.contextNextQueueSectionHeader?.refresh()
    }

    func clearUserQueue() {
        guard self.player.userQueue.count > 0 else { return }
        self.tableView?.beginUpdates()
        var indexPaths = [IndexPath]()
        for i in 0...self.player.userQueue.count-1 {
            indexPaths.append(IndexPath(row: i, section: PlayerSectionCategory.userQueue.rawValue))
        }
        self.tableView?.deleteRows(at: indexPaths, with: .fade)
        self.player.clearUserQueue()
        self.tableView?.endUpdates()
        self.refreshUserQueueSectionHeader()
    }

    func convertCellViewToPlayerIndex(cell: PlayableTableCell) -> PlayerIndex? {
        guard let indexPath = self.tableView?.indexPath(for: cell),
              let playerIndex = PlayerIndex.create(from: indexPath) else { return nil }
        return playerIndex
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return PlayerSectionCategory.allCases.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return nil
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
            if player.userQueue.isEmpty {
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
        case .contextPrev, .contextNext:
            return clearEmptySectionFooter
        default:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch PlayerSectionCategory(rawValue: section) {
        case .contextPrev: return self.player.prevQueue.count
        case .userQueue: return self.player.userQueue.count
        case .contextNext: return self.player.nextQueue.count
        default: return 0
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let sectionCategors = PlayerSectionCategory(rawValue: indexPath.section)
        switch sectionCategors {
        case .contextPrev, .userQueue, .contextNext, .none:
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
        case .contextPrev, .userQueue, .contextNext:
            let cell: PlayableTableCell = tableView.dequeueCell(for: tableView, at: indexPath)

            guard let playerIndex = PlayerIndex.create(from: indexPath),
                  let playable = player.getPlayable(at: playerIndex)
            else { return cell }
            cell.backgroundColor = .clear
            cell.display(
                playable: playable,
                playContextCb: {(_) in PlayContext()},
                rootView: self,
                playerIndexCb: convertCellViewToPlayerIndex)
            return cell
        default:
            return UITableViewCell()
        }

    }

    // Override to allow editing only for certain rows
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        switch PlayerSectionCategory(rawValue: indexPath.section) {
        case .contextPrev, .userQueue, .contextNext: return true
        default: return false
        }
    }

    // Override to support editing the table view.
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
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
    func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath, toProposedIndexPath targetIndexPath: IndexPath) -> IndexPath {
        return targetIndexPath
    }

    // Override to support conditional rearranging of the table view.
    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        switch PlayerSectionCategory(rawValue: indexPath.section) {
        case .contextPrev, .userQueue, .contextNext: return true
        default: return false
        }
    }

    /// long press on cell animation (cell content gets smaller)
    private func makeTargetedPreview(for configuration: UIContextMenuConfiguration, willBeShown: Bool) -> UITargetedPreview? {
        guard let identifier = configuration.identifier as? String,
              let tvPreviewInfo = TableViewPreviewInfo.create(fromIdentifier: identifier),
              let indexPath = tvPreviewInfo.indexPath,
              let cell = self.tableView?.cellForRow(at: indexPath) as? PlayableTableCell
        else { return nil }

        let parameters = UIPreviewParameters()
        parameters.backgroundColor = .clear
        return UITargetedPreview(view: cell, parameters: parameters)
    }

    func tableView(_ tableView: UITableView, previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        return makeTargetedPreview(for: configuration, willBeShown: true)
    }

    func tableView(_ tableView: UITableView, previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        return makeTargetedPreview(for: configuration, willBeShown: false)
    }

    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard let playerIndex = PlayerIndex.create(from: indexPath),
              let containable = self.player.getPlayable(at: playerIndex)
        else { return nil }
        let identifier = NSString(string: TableViewPreviewInfo(playableContainerIdentifier: containable.containerIdentifier, indexPath: indexPath).asJSONString())
        return UIContextMenuConfiguration(identifier: identifier, previewProvider: {
            let vc = EntityPreviewVC()
            vc.display(container: containable, on: self)
            return vc
        }) { suggestedActions in
            return EntityPreviewActionBuilder(container: containable, on: self).createMenu()
        }
    }

    func tableView(_ tableView: UITableView, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
        animator.addCompletion {
            if let identifier = configuration.identifier as? String,
               let tvPreviewInfo = TableViewPreviewInfo.create(fromIdentifier: identifier),
               let containerIdentifier = tvPreviewInfo.playableContainerIdentifier,
               let container = self.appDelegate.storage.main.library.getContainer(identifier: containerIdentifier) {
                EntityPreviewActionBuilder(container: container, on: self).performPreviewTransition()
            }
        }
    }
}

extension QueueVC: UITableViewDragDelegate {
    func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        return []
    }

    func tableView(_ tableView: UITableView, dragPreviewParametersForRowAt indexPath: IndexPath) -> UIDragPreviewParameters? {
        let parameter = UIDragPreviewParameters()
        parameter.backgroundColor = .clear
        return parameter
    }
}

extension QueueVC: UITableViewDropDelegate {
    func tableView(_ tableView: UITableView, canHandle session: UIDropSession) -> Bool {
        return false
    }

    // Local drags with one item go through the existing tableView(_:moveRowAt:to:) method on the data source
    func tableView(_ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator) {}

    func tableView(_ tableView: UITableView, dropSessionDidEnd session: UIDropSession) {}

    func tableView(_ tableView: UITableView, dropPreviewParametersForRowAt indexPath: IndexPath) -> UIDragPreviewParameters? {
        let parameter = UIDragPreviewParameters()
        parameter.backgroundColor = .clear
        return parameter
    }
}

extension QueueVC: MusicPlayable {
    func refresh() {
        self.refreshContextQueueSectionHeader()
        self.refreshUserQueueSectionHeader()
    }

    func reloadData() {
        self.tableView?.reloadData()
    }

    func didStartPlaying() {
        self.reloadData()
        self.refresh()
    }

    func didStopPlaying() {
        self.reloadData()
        self.refresh()
    }

    func didPlaylistChange() {
        self.reloadData()
        self.refresh()
    }

    func didShuffleChange() {
        self.reloadData()
        self.refresh()
    }

    func didRepeatChange() {
        self.reloadData()
        self.refresh()
    }

    func didStartPlayingFromBeginning() {}
    func didPause() {}
    func didElapsedTimeChange() {}
    func didArtworkChange() {}
    func didPlaybackRateChange() {}
}

#endif
