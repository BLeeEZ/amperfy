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
    #if targetEnvironment(macCatalyst)
      config.baseForegroundColor = .label
      config.baseBackgroundColor = .clear
    #else
      config.baseForegroundColor = !isSelected ? .label : .systemBackground
      config.baseBackgroundColor = !isSelected ? .clear : .label
    #endif
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

  // MARK: Text size

  /// Keeps the rows up to date with the user's text size (see `TextScaling`): whenever it
  /// changes, the table is reloaded, so that cells and `tableView(_:heightForRowAt:)` pick up
  /// the new size. Tables with one height for all rows pass it as `rowHeight`: it is applied to
  /// `rowHeight` and `estimatedRowHeight` now and before every reload.
  func reloadOnTextSizeChange(rowHeight: (@MainActor () -> CGFloat)? = nil) {
    let applyRowHeight = { (tableView: UITableView) in
      guard let rowHeight else { return }
      tableView.rowHeight = rowHeight()
      tableView.estimatedRowHeight = tableView.rowHeight
    }
    applyRowHeight(self)
    registerForTraitChanges(
      [UITraitPreferredContentSizeCategory.self],
      handler: { (self: Self, previousTraitCollection: UITraitCollection) in
        applyRowHeight(self)
        self.reloadData()
      }
    )
  }
}

// MARK: - TextScaling

/// Proxy for everything that scales with the user's text size: fonts of `ScaledLabel`s, row
/// heights and other text dependent sizes. The text size is the system's or the in-app text size
/// (Settings > Display), which `AppDelegate.applyTextSize()` sets as `preferredContentSizeCategory`
/// trait override on all windows, so views get notified like for Dynamic Type changes.
/// - iOS/iPadOS: forwards to Dynamic Type (text styles in the xibs, `UIFontMetrics`).
/// - Mac Catalyst: macOS has no Dynamic Type, text styles always have the same size. Fonts and
///   sizes are scaled with the factors of the iOS text sizes instead.
@MainActor
enum TextScaling {
  /// Text sizes that can be chosen in the settings
  static let textSizes: [UIContentSizeCategory] = [
    .extraSmall, .small, .medium, .large, .extraLarge, .extraExtraLarge, .extraExtraExtraLarge,
    .accessibilityMedium, .accessibilityLarge, .accessibilityExtraLarge,
    .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge,
  ]

  /// The in-app text size, nil: system text size (iOS) / default text size (Mac)
  static var textSize: UIContentSizeCategory?

  /// Size of the body text style on iOS for each text size (17pt at the default size)
  private static let bodySizes: [UIContentSizeCategory: CGFloat] = [
    .extraSmall: 14, .small: 15, .medium: 16, .large: 17, .extraLarge: 19,
    .extraExtraLarge: 21, .extraExtraExtraLarge: 23, .accessibilityMedium: 28,
    .accessibilityLarge: 33, .accessibilityExtraLarge: 40, .accessibilityExtraExtraLarge: 47,
    .accessibilityExtraExtraExtraLarge: 53,
  ]

  /// `.footnote` scales slightly stronger than `.body`, so scaled sizes leave enough room
  private static let metrics = UIFontMetrics(forTextStyle: .footnote)

  /// iOS: unchanged, Dynamic Type scales the font. Mac: scaled to the traits' text size.
  static func scaledFont(_ font: UIFont, compatibleWith traits: UITraitCollection) -> UIFont {
    #if targetEnvironment(macCatalyst)
      return font.withSize((font.pointSize * factor(for: currentTextSize(traits))).rounded())
    #else
      return font
    #endif
  }

  /// `value` at the default text size, scaled to the text size of `traits` (or the app's)
  static func scaledValue(
    _ value: CGFloat,
    compatibleWith traits: UITraitCollection? = nil,
    maximum: UIContentSizeCategory? = nil
  )
    -> CGFloat {
    var textSize = currentTextSize(traits)
    if let maximum, textSize > maximum {
      textSize = maximum
    }
    #if targetEnvironment(macCatalyst)
      return value * factor(for: textSize)
    #else
      return metrics.scaledValue(
        for: value,
        compatibleWith: UITraitCollection(preferredContentSizeCategory: textSize)
      )
    #endif
  }

  /// The traits of a view in a window already contain the in-app text size (and its maximum)
  private static func currentTextSize(_ traits: UITraitCollection?) -> UIContentSizeCategory {
    if let traitsTextSize = traits?.preferredContentSizeCategory,
       traitsTextSize != .unspecified {
      return traitsTextSize
    }
    return textSize ?? UIApplication.shared.preferredContentSizeCategory
  }

  private static func factor(for textSize: UIContentSizeCategory) -> CGFloat {
    (bodySizes[textSize] ?? 17.0) / 17.0
  }
}

// MARK: - ScaledLabel

/// Label whose text scales with the user's text size. Use it as custom class in xibs together
/// with a text style font (incl. size class variations).
/// - iOS/iPadOS: a plain `UILabel`, Dynamic Type scales the text style.
/// - Mac Catalyst: every font that gets assigned (by the xib or code) is the unscaled base font,
///   the label displays it scaled by `TextScaling`.
class ScaledLabel: UILabel {
  #if targetEnvironment(macCatalyst)
    private var unscaledFont: UIFont?
    private var isRegisteredForTextSizeChanges = false

    override var font: UIFont! {
      get { super.font }
      set {
        unscaledFont = newValue
        guard newValue != nil else {
          super.font = nil
          return
        }
        applyScaledFont()
      }
    }

    override func didMoveToWindow() {
      super.didMoveToWindow()
      if !isRegisteredForTextSizeChanges {
        isRegisteredForTextSizeChanges = true
        registerForTraitChanges(
          [UITraitPreferredContentSizeCategory.self],
          handler: { (self: Self, previousTraitCollection: UITraitCollection) in
            self.applyScaledFont()
          }
        )
      }
      applyScaledFont()
    }

    private func applyScaledFont() {
      if unscaledFont == nil {
        unscaledFont = super.font
      }
      guard let unscaledFont else { return }
      super.font = TextScaling.scaledFont(unscaledFont, compatibleWith: traitCollection)
    }
  #endif
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

  /// `@objc` so that subclasses can override it (e.g. `KeyboardFocusableListCell`)
  @objc
  func markAsFocused() {
    let focuseBackground = UIView(frame: bounds)
    focuseBackground.backgroundColor = .systemGray4
    backgroundView = focuseBackground
  }

  @objc
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

extension UISearchBar {
  /// Whether the list is limited to cached entries. Mac Catalyst has no scope bar
  /// (see `configureSearchController`), so offline mode alone decides there.
  @MainActor
  var isCachedScopeSelected: Bool {
    if scopeButtonTitles?.count ?? 0 > 1 {
      return selectedScopeButtonIndex == 1
    }
    return appDelegate.storage.settings.user.isOfflineMode
  }
}
