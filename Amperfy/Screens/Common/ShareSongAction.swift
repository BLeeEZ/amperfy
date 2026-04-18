//
//  ShareSongAction.swift
//  Amperfy
//
//  Created by the Amperfy spike (Feature E — Share).
//  Copyright (c) 2026 Olivier Butler. All rights reserved.
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

/// Presents the iOS share sheet for a single song. If the song is not yet
/// cached locally, triggers a download first and shows a progress alert.
/// See BACKLOG.md §PR 6.
@MainActor
enum ShareSongAction {
  static func share(
    song: AbstractPlayable,
    from sourceView: UIView,
    presenter: UIViewController,
    appDelegate: AppDelegate
  ) {
    // Already cached — present immediately.
    if let fileURL = cachedFileURL(for: song) {
      presentActivityController(
        for: song,
        fileURL: fileURL,
        sourceView: sourceView,
        presenter: presenter
      )
      return
    }

    // Not cached — trigger download, poll for completion.
    guard let accountInfo = song.account?.info else { return }

    let progressAlert = UIAlertController(
      title: "Downloading\u{2026}",
      message: song.title,
      preferredStyle: .alert
    )
    var cancelled = false
    progressAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
      cancelled = true
    })
    presenter.present(progressAlert, animated: true)

    appDelegate.getMeta(accountInfo).playableDownloadManager
      .download(object: song)

    // Poll for the file to appear on disk (download manager is fire-and-forget).
    Task { @MainActor in
      for _ in 0 ..< 120 { // up to ~60 seconds at 0.5s intervals
        try? await Task.sleep(for: .milliseconds(500))
        if cancelled { return }
        if let fileURL = cachedFileURL(for: song) {
          progressAlert.dismiss(animated: true) {
            presentActivityController(
              for: song,
              fileURL: fileURL,
              sourceView: sourceView,
              presenter: presenter
            )
          }
          return
        }
      }
      // Timed out.
      progressAlert.dismiss(animated: true) {
        let errorAlert = UIAlertController(
          title: "Download failed",
          message: "Couldn't download this song. Please try again.",
          preferredStyle: .alert
        )
        errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
        presenter.present(errorAlert, animated: true)
      }
    }
  }

  private static func cachedFileURL(for song: AbstractPlayable) -> URL? {
    guard let relPath = song.relFilePath,
          let absoluteURL = CacheFileManager.shared.getAbsoluteAmperfyPath(relFilePath: relPath),
          FileManager.default.fileExists(atPath: absoluteURL.path)
    else { return nil }
    return absoluteURL
  }

  private static func presentActivityController(
    for song: AbstractPlayable,
    fileURL: URL,
    sourceView: UIView,
    presenter: UIViewController
  ) {
    let artistName = song.asSong?.artist?.name ?? "Unknown artist"
    let textItem = "\(song.title) \u{2014} \(artistName)"

    // Rename to "Song Title - Artist.ext" for a friendly filename in the share sheet
    let safeFileName = "\(song.title) - \(artistName)"
      .replacingOccurrences(of: "/", with: "-")
      .replacingOccurrences(of: ":", with: "-")
    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(safeFileName)
      .appendingPathExtension(fileURL.pathExtension)
    try? FileManager.default.removeItem(at: tempURL)
    try? FileManager.default.copyItem(at: fileURL, to: tempURL)
    let shareURL = FileManager.default.fileExists(atPath: tempURL.path) ? tempURL : fileURL

    let activityVC = UIActivityViewController(
      activityItems: [shareURL, textItem],
      applicationActivities: nil
    )
    activityVC.popoverPresentationController?.sourceView = sourceView
    activityVC.popoverPresentationController?.sourceRect = sourceView.bounds
    if shareURL != fileURL {
      activityVC.completionWithItemsHandler = { _, _, _, _ in
        try? FileManager.default.removeItem(at: shareURL)
      }
    }
    presenter.present(activityVC, animated: true)
  }
}
