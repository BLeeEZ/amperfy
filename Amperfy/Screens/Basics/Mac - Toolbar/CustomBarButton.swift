//
//  CustomBarButton.swift
//  Amperfy
//
//  Created by David Klopp on 22.08.24.
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

import Foundation
import UIKit

#if targetEnvironment(macCatalyst)

  class MacSnapshotButton: UIButton {
    /// override this to allow snapshots: this is needed in macOS to show all tabs and create a new tab
    override func drawHierarchy(in rect: CGRect, afterScreenUpdates afterUpdates: Bool) -> Bool {
      true
    }
  }

  // MacOS BarButtonItems can not be disabled. Thats, why we create a custom BarButtonItem.
  class CustomBarButton: UIBarButtonItem, Refreshable {
    static let defaultPointSize: CGFloat = 18.0
    static let smallPointSize: CGFloat = 14.0
    static let verySmallPointSize: CGFloat = 12.0
    static let defaultSize = CGSize(width: 32, height: 22)

    let pointSize: CGFloat

    var inUIButton: UIButton? {
      customView as? UIButton
    }

    var hovered: Bool = false {
      didSet {
        updateButtonBackgroundColor()
      }
    }

    var active: Bool = false {
      didSet {
        guard let image = inUIButton?.configuration?.image else { return }
        updateImage(image: image)
        updateButtonBackgroundColor()
      }
    }

    var currentTintColor: UIColor {
      if active {
        .label
      } else {
        .secondaryLabel
      }
    }

    var currentBackgroundColor: UIColor {
      if hovered || active {
        .hoveredBackgroundColor
      } else {
        .clear
      }
    }

    func updateButtonBackgroundColor() {
      inUIButton?.backgroundColor = currentBackgroundColor
    }

    func updateImage(image: UIImage) {
      inUIButton?.configuration?.image = image.styleForNavigationBar(
        pointSize: pointSize,
        tintColor: currentTintColor
      )
    }

    func createInUIButton(config: UIButton.Configuration, size: CGSize) -> UIButton? {
      let button = MacSnapshotButton(configuration: config)
      button.imageView?.contentMode = .scaleAspectFit

      // influence the highlighted area
      button.translatesAutoresizingMaskIntoConstraints = false
      button.widthAnchor.constraint(equalToConstant: size.width).isActive = true
      button.heightAnchor.constraint(equalToConstant: size.height).isActive = true

      return button
    }

    override var isEnabled: Bool {
      get { super.isEnabled }
      set(newValue) {
        super.isEnabled = newValue
        customView?.isUserInteractionEnabled = newValue
      }
    }

    init(image: UIImage?, pointSize: CGFloat = ControlBarButton.defaultPointSize) {
      self.pointSize = pointSize
      super.init()

      var config = UIButton.Configuration.gray()
      config.macIdiomStyle = .borderless
      config.image = image?.styleForNavigationBar(
        pointSize: self.pointSize,
        tintColor: currentTintColor
      )
      let button = createInUIButton(config: config, size: Self.defaultSize)
      button?.addTarget(self, action: #selector(clicked(_:)), for: .touchUpInside)
      button?.layer.cornerRadius = 5
      self.customView = button

      // Recreate the system button background highlight
      installHoverGestureRecognizer()
    }

    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    private func installHoverGestureRecognizer() {
      let recognizer = UIHoverGestureRecognizer(target: self, action: #selector(hoverButton(_:)))
      inUIButton?.addGestureRecognizer(recognizer)
    }

    @objc
    private func hoverButton(_ recognizer: UIHoverGestureRecognizer) {
      switch recognizer.state {
      case .began:
        hovered = true
      case .cancelled, .ended, .failed:
        hovered = false
      default:
        break
      }
    }

    @objc
    func clicked(_ sender: UIButton) {}

    func reload() {
      updateButtonBackgroundColor()
      guard let image = inUIButton?.configuration?.image else { return }
      updateImage(image: image)
    }
  }

#endif
