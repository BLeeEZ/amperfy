//
//  ShareSongAction.swift
//  Amperfy
//
//  Created by the Olivier Butler 18.04.2026.
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

import LinkPresentation
import UIKit

// MARK: - ShareSongAction

/// Presents the iOS share sheet for a single song. If the song is not yet
/// cached locally, triggers a download first and shows a progress alert.
///
/// No shared state between functions, one prepares the song, one cleans a URL, one presents the sharing activity VC.
@MainActor
public enum ShareSongAction {
  public static func share(
    playable: AbstractPlayable,
    from sourceView: UIView,
    presenter: UIViewController,
    downloadManagerProvider: () -> DownloadManageable?
  ) {
    // Already cached — present immediately.
    if let fileURL = cachedFileURL(for: playable) {
      presentActivityController(
        for: playable,
        fileURL: fileURL,
        sourceView: sourceView,
        presenter: presenter
      )
      return
    }
    guard let downloadManager = downloadManagerProvider() else {
      return
    }

    let progressAlert = UIAlertController(
      title: "Downloading\(CommonString.ellipsis)",
      message: playable.displayString,
      preferredStyle: .alert
    )
    var cancelled = false
    progressAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
      cancelled = true
    })
    presenter.present(progressAlert, animated: true)

    downloadManager.download(object: playable)

    // Poll for the file to appear on disk (download manager is fire-and-forget).
    Task { @MainActor in
      for _ in 0 ..< 120 { // up to ~60 seconds at 0.5s intervals
        try? await Task.sleep(for: .milliseconds(500))
        if cancelled { return }
        if let fileURL = cachedFileURL(for: playable) {
          progressAlert.dismiss(animated: true) {
            presentActivityController(
              for: playable,
              fileURL: fileURL,
              sourceView: sourceView,
              presenter: presenter
            )
          }
          return
        }
      }
      // Timed out, show error
      progressAlert.dismiss(animated: true) {
        let errorAlert = UIAlertController(
          title: "Download failed",
          message: "The download took too long. Please try again.",
          preferredStyle: .alert
        )
        errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
        presenter.present(errorAlert, animated: true)
      }
    }
  }

  private static func cachedFileURL(for playable: AbstractPlayable) -> URL? {
    guard let relPath = playable.relFilePath,
          let absoluteURL = CacheFileManager.shared.getAbsoluteAmperfyPath(relFilePath: relPath),
          FileManager.default.fileExists(atPath: absoluteURL.path)
    else { return nil }
    return absoluteURL
  }

  static func sanitizedFileName(playable: AbstractPlayable) -> String {
    playable.displayString
      .replacingOccurrences(of: "/", with: "-")
      .replacingOccurrences(of: ":", with: "-")
  }

  private static func presentActivityController(
    for playable: AbstractPlayable,
    fileURL: URL,
    sourceView: UIView,
    presenter: UIViewController
  ) {
    let textItem = playable.displayString
    let safeFileName = sanitizedFileName(playable: playable)
    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(safeFileName)
      .appendingPathExtension(fileURL.pathExtension)
    try? FileManager.default.removeItem(at: tempURL)
    try? FileManager.default.copyItem(at: fileURL, to: tempURL)
    let shareURL = FileManager.default.fileExists(atPath: tempURL.path) ? tempURL : fileURL

    let artwork = artworkImage(for: playable)
    let fileItemSource = SongShareItemSource(
      fileURL: shareURL,
      title: textItem,
      artwork: artwork
    )
    let activityVC = UIActivityViewController(
      activityItems: [fileItemSource, textItem],
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

  static func artworkImage(for playable: AbstractPlayable) -> UIImage {
    let settings = AmperKit.shared.storage.settings
    let accountSettings = playable.account.map { settings.accounts.getSetting($0.info) }
      ?? settings.accounts.activeSetting
    return LibraryEntityImage.getImageToDisplayImmediately(
      libraryEntity: playable,
      themePreference: accountSettings.read.themePreference,
      artworkDisplayPreference: accountSettings.read.artworkDisplayPreference,
      useCache: false
    )
  }
}

// MARK: - SongShareItemSource

private final class SongShareItemSource: NSObject, UIActivityItemSource {
  let fileURL: URL
  let title: String
  let artwork: UIImage

  init(fileURL: URL, title: String, artwork: UIImage) {
    self.fileURL = fileURL
    self.title = title
    self.artwork = artwork
  }

  func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController)
    -> Any {
    fileURL
  }

  func activityViewController(
    _ activityViewController: UIActivityViewController,
    itemForActivityType activityType: UIActivity.ActivityType?
  )
    -> Any? {
    fileURL
  }

  func activityViewController(
    _ activityViewController: UIActivityViewController,
    subjectForActivityType activityType: UIActivity.ActivityType?
  )
    -> String {
    title
  }

  func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController)
    -> LPLinkMetadata? {
    let metadata = LPLinkMetadata()
    metadata.title = title
    metadata.originalURL = fileURL
    metadata.iconProvider = NSItemProvider(object: artwork)
    metadata.imageProvider = NSItemProvider(object: artwork)
    return metadata
  }
}
