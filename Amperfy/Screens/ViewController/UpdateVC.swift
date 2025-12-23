//
//  UpdateVC.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 25.04.24.
//  Copyright (c) 2019 Maximilian Bauer. All rights reserved.
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

// MARK: - UpdateVC

class UpdateVC: UIViewController {
  var tickCount: Int = 0
  var oprationPercent: Float = 0.0
  var totalTickCount: Int = 1

  @IBOutlet
  weak var progressBar: UIProgressView!
  @IBOutlet
  weak var progressLabel: UILabel!
  @IBOutlet
  weak var progressInfo: UILabel!
  @IBOutlet
  weak var activitySpinner: UIActivityIndicatorView!

  override func viewDidLoad() {
    super.viewDidLoad()
    progressBar.setProgress(0.0, animated: true)
    progressInfo.text = ""
    progressLabel.text = String(format: "%.1f", 0.0) + "%"
    appDelegate.isKeepScreenAlive = true
  }

  override func viewDidAppear(_ animated: Bool) {
    appDelegate.eventLogger.supressAlerts = true

    Task { @MainActor in
      do {
        try await self.appDelegate.libraryUpdater.performLibraryUpdateWithStatus(notifier: self)
      } catch {
        // cancle and do nothing
      }
      self.progressInfo.text = "Done"
      self.activitySpinner.stopAnimating()
      self.activitySpinner.isHidden = true
      self.progressLabel.isHidden = true

      self.appDelegate.isKeepScreenAlive = false
      self.appDelegate.eventLogger.supressAlerts = false
      self.appDelegate.startManagerForNormalOperation()

      guard let mainScene = AppDelegate.mainSceneDelegate else { return }
      if let accountInfo = self.appDelegate.storage.settings.accounts.active {
        let account = self.appDelegate.storage.main.library.getAccount(info: accountInfo)
        mainScene
          .replaceMainRootViewController(vc: AppStoryboard.Main.segueToMainWindow(account: account))
      } else {
        mainScene.replaceMainRootViewController(vc: AppStoryboard.Main.segueToLogin())
      }
    }
  }

  private func updateSyncInfo(infoText: String? = nil, percentParsed: Float = 0.0) {
    if let infoText = infoText {
      progressInfo.text = infoText
    }
    progressBar.setProgress(percentParsed, animated: percentParsed != 0.0)
    progressLabel.text = String(format: "%.1f", percentParsed * 100) + "%"
  }
}

// MARK: LibraryUpdaterCallbacks

extension UpdateVC: LibraryUpdaterCallbacks {
  nonisolated func startOperation(name: String, totalCount: Int) {
    Task { @MainActor in
      self.tickCount = 0
      self.oprationPercent = 0.0
      self.totalTickCount = totalCount > 0 ? totalCount : 1

      if totalCount > 0 {
        self.activitySpinner.stopAnimating()
        self.activitySpinner.isHidden = true
      } else {
        self.activitySpinner.startAnimating()
        self.activitySpinner.isHidden = false
      }
      self.progressLabel.isHidden = totalCount <= 0

      self.updateSyncInfo(infoText: name, percentParsed: 0.0)
    }
  }

  nonisolated func tickOperation() {
    Task { @MainActor in
      tickCount += 1
      var parsePercent: Float = 0.0
      if self.totalTickCount > 0 {
        parsePercent = min(Float(self.tickCount) / Float(self.totalTickCount), 1.0)
      }
      let percentDiff = Int(parsePercent * 1000) - Int(self.oprationPercent * 1000)
      if percentDiff > 0 {
        self.updateSyncInfo(percentParsed: parsePercent)
      }
      self.oprationPercent = parsePercent
    }
  }
}
