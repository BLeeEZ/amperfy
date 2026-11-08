//
//  NotificationDetailVC.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 04.03.24.
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

class NotificationDetailVC: UIViewController {
  @IBOutlet
  weak var descriptionTextView: UITextView!

  var topic = ""
  var message = ""
  var logType = LogEntryType.info

  override func viewDidLoad() {
    super.viewDidLoad()
    view.setBackgroundBlur(style: .prominent)
    // system close button: drawn by the system on every platform (glass on iOS and macOS 26)
    navigationItem.rightBarButtonItem = UIBarButtonItem(
      systemItem: .close,
      primaryAction: UIAction { [weak self] _ in self?.pressedClose() }
    )
    let barAppearance = UINavigationBarAppearance()
    barAppearance.configureWithTransparentBackground()
    navigationItem.standardAppearance = barAppearance
    navigationItem.scrollEdgeAppearance = barAppearance
    // the scroll view starts below the navigation bar (safe area); the text view does not scroll,
    // an inset of its own would push the text out of its bounds
    descriptionTextView.contentInsetAdjustmentBehavior = .never
    descriptionTextView.backgroundColor = .clear
  }

  override func viewIsAppearing(_ animated: Bool) {
    super.viewIsAppearing(animated)
    // the size class is only known once the view is in the presentation; the sheet belongs to the
    // navigation controller, which sheetPresentationController returns for its child
    if let sheet = sheetPresentationController {
      sheet.detents = traitCollection.horizontalSizeClass == .compact
        ? [.large(), .medium()]
        : [.large()]
    }
    refresh()
  }

  func display(title: String, message: String, type: LogEntryType) {
    topic = title
    self.message = message
  }

  func refresh() {
    title = topic
    descriptionTextView.text = message
  }

  func pressedClose() {
    dismiss(animated: true)
  }
}
