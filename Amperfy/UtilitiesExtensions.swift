//
//  UtilitiesExtensions.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 06.06.22.
//  Copyright (c) 2022 Maximilian Bauer. All rights reserved.
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
import MarqueeLabel
import os.log
import SwiftUI
import UIKit

extension MarqueeLabel {
  func applyAmperfyStyle() {
    if trailingBuffer != 30.0 {
      trailingBuffer = 30.0
    }
    if leadingBuffer != 0.0 {
      leadingBuffer = 0.0
    }
    if animationDelay != 2.0 {
      animationDelay = 2.0
    }
    if type != .continuous {
      type = .continuous
    }
    speed = .rate(30.0)
    if fadeLength != 10.0 {
      fadeLength = 10.0
    }
  }
}

extension UIColor {
  static let hardLabelColor = UIColor(named: "hardLabelColor")
}

extension Color {
  static let error = Color.red
  static let success = Color.green

  // MARK: - Text Colors

  static let lightText = Color(UIColor.lightText)
  static let darkText = Color(UIColor.darkText)
  static let placeholderText = Color(UIColor.placeholderText)

  // MARK: - Label Colors

  static let label = Color(UIColor.label)
  static let secondaryLabel = Color(UIColor.secondaryLabel)
  static let tertiaryLabel = Color(UIColor.tertiaryLabel)
  static let quaternaryLabel = Color(UIColor.quaternaryLabel)

  // MARK: - Background Colors

  static let systemBackground = Color(UIColor.systemBackground)
  static let secondarySystemBackground = Color(UIColor.secondarySystemBackground)
  static let tertiarySystemBackground = Color(UIColor.tertiarySystemBackground)

  // MARK: - Fill Colors

  static let systemFill = Color(UIColor.systemFill)
  static let secondarySystemFill = Color(UIColor.secondarySystemFill)
  static let tertiarySystemFill = Color(UIColor.tertiarySystemFill)
  static let quaternarySystemFill = Color(UIColor.quaternarySystemFill)

  // MARK: - Grouped Background Colors

  static let systemGroupedBackground = Color(UIColor.systemGroupedBackground)
  static let secondarySystemGroupedBackground = Color(UIColor.secondarySystemGroupedBackground)
  static let tertiarySystemGroupedBackground = Color(UIColor.tertiarySystemGroupedBackground)

  // MARK: - Gray Colors

  static let systemGray = Color(UIColor.systemGray)
  static let systemGray2 = Color(UIColor.systemGray2)
  static let systemGray3 = Color(UIColor.systemGray3)
  static let systemGray4 = Color(UIColor.systemGray4)
  static let systemGray5 = Color(UIColor.systemGray5)
  static let systemGray6 = Color(UIColor.systemGray6)

  // MARK: - Other Colors

  static let separator = Color(UIColor.separator)
  static let opaqueSeparator = Color(UIColor.opaqueSeparator)
  static let link = Color(UIColor.link)

  // MARK: System Colors

  static let systemBlue = Color(UIColor.systemBlue)
  static let systemPurple = Color(UIColor.systemPurple)
  static let systemGreen = Color(UIColor.systemGreen)
  static let systemYellow = Color(UIColor.systemYellow)
  static let systemOrange = Color(UIColor.systemOrange)
  static let systemPink = Color(UIColor.systemPink)
  static let systemRed = Color(UIColor.systemRed)
  static let systemTeal = Color(UIColor.systemTeal)
  static let systemIndigo = Color(UIColor.systemIndigo)
}

public func withPopupAnimation<Result>(_ body: () throws -> Result) rethrows -> Result {
  try withAnimation(.easeInOut(duration: 0.2)) {
    try body()
  }
}

extension View {
  var appDelegate: AppDelegate {
    (UIApplication.shared.delegate as! AppDelegate)
  }
}

extension UIColor {
  static let slideOverBackgroundColor: UIColor = .systemBackground.withAlphaComponent(0.5)
  static let hoveredBackgroundColor: UIColor = .systemGray2.withAlphaComponent(0.2)
}

extension UIButton.Configuration {
  static func player(isSelected: Bool) -> UIButton.Configuration {
    var config = UIButton.Configuration.tinted()
    if isSelected {
      config.background.strokeColor = .label
      config.background.strokeWidth = 1.0
      config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(scale: .medium)
    }
    config.buttonSize = .small
    config.baseForegroundColor = !isSelected ? .label : .systemBackground
    config.baseBackgroundColor = !isSelected ? .clear : .label
    config.cornerStyle = .medium
    return config
  }

  static func playerRound() -> UIButton.Configuration {
    var config = UIButton.Configuration.gray()
    config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(scale: .medium)
    config.buttonSize = .small
    return config
  }
}

extension UIView {
  static let forceTouchClickLimit: Float = 1.0

  func normalizedForce(touches: Set<UITouch>) -> Float? {
    guard is3DTouchAvailable, let touch = touches.first else { return nil }
    let maximumForce = touch.maximumPossibleForce
    let force = touch.force
    let normalizedForce = (force / maximumForce)
    return Float(normalizedForce)
  }

  func isForceClicked(_ touches: Set<UITouch>) -> Bool {
    guard let force = normalizedForce(touches: touches) else { return false }
    if force < UIView.forceTouchClickLimit {
      return false
    } else {
      return true
    }
  }

  var is3DTouchAvailable: Bool {
    forceTouchCapability() == .available
  }

  func forceTouchCapability() -> UIForceTouchCapability {
    UIApplication.shared.mainWindow?.rootViewController?.traitCollection
      .forceTouchCapability ?? .unknown
  }

  public func setBackgroundBlur(style: UIBlurEffect.Style, alpha: CGFloat = 1.0) {
    backgroundColor = UIColor.clear
    let blurEffect = UIBlurEffect(style: style)
    let blurEffectView = UIVisualEffectView(effect: blurEffect)
    blurEffectView.alpha = alpha
    blurEffectView.frame = bounds
    blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    insertSubview(blurEffectView, at: 0)
  }

  func addLeftSideBorder() {
    let separator = UIView()
    separator.backgroundColor = .separator
    addSubview(separator)
    separator.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
      separator.widthAnchor.constraint(equalToConstant: 1),
      separator.leadingAnchor.constraint(equalTo: leadingAnchor),
      separator.topAnchor.constraint(equalTo: topAnchor),
      separator.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
  }

  func addTopSideBorder() {
    let separator = UIView()
    separator.backgroundColor = .separator
    addSubview(separator)
    separator.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
      separator.heightAnchor.constraint(equalToConstant: 1),
      separator.leadingAnchor.constraint(equalTo: leadingAnchor),
      separator.topAnchor.constraint(equalTo: topAnchor),
      separator.trailingAnchor.constraint(equalTo: trailingAnchor),
    ])
  }
}

extension UINavigationController {
  func replaceCurrentlyActiveVC(with vc: UIViewController, animated: Bool) {
    var vcs = viewControllers
    vcs = vcs.dropLast()
    vcs.append(vc)
    setViewControllers(vcs, animated: animated)
  }
}

extension UITableView {
  func register(nibName: String) {
    register(UINib(nibName: nibName, bundle: nil), forCellReuseIdentifier: nibName)
  }

  func dequeueCell<CellType: UITableViewCell>(
    for tableView: UITableView,
    at indexPath: IndexPath
  )
    -> CellType {
    guard let cell = dequeueReusableCell(
      withIdentifier: CellType.typeName,
      for: indexPath
    ) as? CellType else {
      os_log(.error, "The dequeued cell is not an instance of %s", CellType.typeName)
      return CellType()
    }
    return cell
  }

  func hasRowAt(indexPath: IndexPath) -> Bool {
    indexPath.section < numberOfSections && indexPath
      .row < numberOfRows(inSection: indexPath.section)
  }
}

extension UICollectionView {
  func hasItemAt(indexPath: IndexPath) -> Bool {
    indexPath.section < numberOfSections && indexPath
      .row < numberOfItems(inSection: indexPath.section)
  }
}

@MainActor
extension UITableViewController {
  func dequeueCell<CellType: UITableViewCell>(
    for tableView: UITableView,
    at indexPath: IndexPath
  )
    -> CellType {
    self.tableView.dequeueCell(for: tableView, at: indexPath)
  }

  func refreshAllVisibleCells() {
    let visibleIndexPaths = tableView.visibleCells.compactMap { tableView.indexPath(for: $0) }
    tableView.reconfigureRows(at: visibleIndexPaths)
  }

  func exectueAfterAnimation(body: @escaping () -> ()) {
    Task { @MainActor in
      body()
    }
  }
}

extension UIViewController {
  var typeName: String {
    Self.typeName
  }
}

extension NSObject {
  @MainActor
  var appDelegate: AppDelegate {
    (UIApplication.shared.delegate as! AppDelegate)
  }
}

extension UIApplication {
  var mainWindow: UIWindow? {
    let scenes = UIApplication.shared.connectedScenes
    for uiScene in scenes {
      if let windowScene = uiScene as? UIWindowScene {
        for window in windowScene.windows {
          if window.isKeyWindow {
            return window
          }
        }
      }
    }
    return nil
  }
}

extension UITraitCollection {
  static let maxDisplayScale = UITraitCollection(displayScale: 3.0)
}

extension UITableViewCell {
  func animateActivation() {
    UIView.animate(withDuration: 0.2, animations: {
      self.markAsFocused()
    }, completion: { _ in
      self.markAsFocused()
      UIView.animate(withDuration: 0.2, animations: {
        self.markAsUnfocused()
      }, completion: { _ in
        self.markAsUnfocused()
      })
    })
  }

  func markAsFocused() {
    backgroundColor = .systemGray4
  }

  func markAsUnfocused() {
    backgroundColor = .clear
  }
}

extension UICollectionViewCell {
  func animateActivation() {
    UIView.animate(withDuration: 0.2, animations: {
      self.markAsFocused()
    }, completion: { _ in
      self.markAsFocused()
      UIView.animate(withDuration: 0.2, animations: {
        self.markAsUnfocused()
      }, completion: { _ in
        self.markAsUnfocused()
      })
    })
  }

  func markAsFocused() {
    let focuseBackground = UIView(frame: bounds)
    focuseBackground.backgroundColor = .systemGray4
    backgroundView = focuseBackground
  }

  func markAsUnfocused() {
    backgroundView = nil
  }
}

extension UIMenu {
  /// rebuilds menu on every access
  static func lazyMenu(
    title: String = "",
    builder: @escaping () -> [UIMenuElement]
  )
    -> UIMenu {
    UIMenu(title: title, children: [
      UIDeferredMenuElement.uncached { completion in
        let actions = builder()
        completion(actions)
      },
    ])
  }
}

extension UIImage {
  func carPlayImage(carTraitCollection traits: UITraitCollection) -> UIImage {
    let imageAsset = UIImageAsset()
    imageAsset.register(self, with: traits)
    return imageAsset.image(with: traits)
  }
}

extension UICollectionViewLayout {
  static var verticalLayout: UICollectionViewFlowLayout {
    let layout = UICollectionViewFlowLayout()
    layout.scrollDirection = .vertical
    return layout
  }
}

extension UIDevice.BatteryState {
  public var description: String {
    switch self {
    case .unknown:
      return "unknown"
    case .unplugged:
      return "unplugged"
    case .charging:
      return "charging"
    case .full:
      return "full"
    @unknown default:
      return "@unknown default"
    }
  }
}

/// This fixes in swiftui mutliple picker views side by side to overlapp their touch areas
/// This is effective in addition to use .clipped() which only fixes the overlapping area visually
extension UIPickerView {
  open override var intrinsicContentSize: CGSize {
    CGSize(width: UIView.noIntrinsicMetric, height: 150)
  }
}

extension Notification.Name {
  static let LibraryItemsChanged = Notification.Name("de.familie-zimba.Amperfy.LibraryItemsChanged")
}

extension UIViewController {
  @objc
  var sceneTitle: String? { nil }

  func extendSafeAreaToAccountForMiniPlayer() {
    guard let hostVC = AppDelegate.mainWindowHostVC else { return }
    additionalSafeAreaInsets = UIEdgeInsets(
      top: 0,
      left: 0,
      bottom: hostVC.getSafeAreaExtension(),
      right: 0
    )
  }
}
