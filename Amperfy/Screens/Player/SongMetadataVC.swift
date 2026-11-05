//
//  SongMetadataVC.swift
//  Amperfy
//
//  Created for iMusify
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

// MARK: - SongMetadataVC

class SongMetadataVC: UIViewController {
  var playable: AbstractPlayable?
  private var amperKit: AmperKit { AmperKit.shared }

  private let scrollView = UIScrollView()
  private let stackView = UIStackView()
  private var isUserDownloaded = false

  override func viewDidLoad() {
    super.viewDidLoad()

    // Dynamic background based on light/dark mode
    view.backgroundColor = UIColor { traitCollection in
      if traitCollection.userInterfaceStyle == .dark {
        return UIColor.black.withAlphaComponent(0.65)
      } else {
        return UIColor.white.withAlphaComponent(0.45)
      }
    }

    setupScrollView()
    setupBorderOverlay()
    buildMetadataContent()
  }

  private func setupBorderOverlay() {
    let borderView = UIView()
    borderView.translatesAutoresizingMaskIntoConstraints = false
    borderView.backgroundColor = .clear
    borderView.isUserInteractionEnabled = false
    borderView.layer.cornerRadius = 35
    borderView.layer.borderWidth = 1.0
    borderView.layer.borderColor = UIColor.separator.cgColor
    view.addSubview(borderView)

    NSLayoutConstraint.activate([
      borderView.topAnchor.constraint(equalTo: view.topAnchor),
      borderView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      borderView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      borderView.bottomAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.bottomAnchor
      ),
    ])
  }

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    for subview in view.subviews where subview.layer.borderWidth > 0 {
      subview.layer.borderColor = UIColor.separator.cgColor
    }
  }

  private func setupScrollView() {
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(scrollView)

    stackView.translatesAutoresizingMaskIntoConstraints = false
    stackView.axis = .vertical
    stackView.spacing = 12
    scrollView.addSubview(stackView)

    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: view.topAnchor),
      scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

      stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
      stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
      stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
      stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -16),
      stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32),
    ])
  }

  private func buildMetadataContent() {
    guard let playable = playable else { return }

    // General Section
    var generalRows: [(String, String)] = []
    generalRows.append(("Title", playable.title))

    if let song = playable.asSong {
      generalRows.append(("Artist", song.artist?.name ?? ""))
      generalRows.append(("Album", song.album?.name ?? ""))
      if let album = song.album, let albumArtist = album.artist,
         albumArtist.name != song.artist?.name {
        generalRows.append(("Album Artist", albumArtist.name))
      }
      generalRows.append(("Genre", song.genre?.name ?? ""))
    }

    generalRows.append(("Composer", playable.composer ?? ""))
    generalRows.append(("Track", playable.track > 0 ? "\(playable.track)" : ""))
    generalRows.append(("Disc", playable.disk ?? ""))
    generalRows.append(("Year", playable.year > 0 ? "\(playable.year)" : ""))
    generalRows.append((
      "Duration",
      playable.duration > 0 ? playable.duration.asDurationString : ""
    ))

    if let song = playable.asSong {
      generalRows.append(("Rating", song.rating > 0 ? "\(song.rating) / 5" : "Not rated"))
      generalRows.append(("Favorite", song.isFavorite ? "Yes" : "No"))
      generalRows.append(("Play Count", "\(song.playCount)"))
    }

    generalRows.append(("Comment", playable.comment ?? ""))

    addSection(title: "Song Info", rows: generalRows)

    // Technical Section
    var technicalRows: [(String, String)] = []
    let bitrateKbps = playable.bitrate > 0 ? "\((playable.bitrate + 500) / 1000) kbps" : ""
    technicalRows.append(("Bitrate", bitrateKbps))
    technicalRows.append(("Format", playable.contentType ?? ""))
    let fileSizeStr = playable.size > 0
      ? String(format: "%.2f MB", Double(playable.size) / (1024 * 1024))
      : ""
    technicalRows.append(("File Size", fileSizeStr))
    technicalRows.append(("ID", playable.id))

    addSection(title: "Technical", rows: technicalRows)

    // File Location Section (stacked layout for long paths)
    let nsPath = (playable.path ?? "") as NSString
    let directory = nsPath.deletingLastPathComponent
    let filename = nsPath.lastPathComponent
    var locationRows: [(String, String)] = []
    locationRows.append(("Directory", directory))
    locationRows.append(("Filename", filename == "." ? "" : filename))
    addStackedSection(title: "File Location", rows: locationRows)

    // ReplayGain Section
    var replayGainRows: [(String, String)] = []
    let trackGainSign = playable.replayGainTrackGain >= 0 ? "+" : ""
    replayGainRows.append((
      "Track Gain",
      playable.replayGainTrackGain != 0
        ? String(format: "%@%.2f dB", trackGainSign, playable.replayGainTrackGain) : ""
    ))
    replayGainRows.append((
      "Track Peak",
      playable.replayGainTrackPeak != 0
        ? String(format: "%.6f", playable.replayGainTrackPeak) : ""
    ))
    let albumGainSign = playable.replayGainAlbumGain >= 0 ? "+" : ""
    replayGainRows.append((
      "Album Gain",
      playable.replayGainAlbumGain != 0
        ? String(format: "%@%.2f dB", albumGainSign, playable.replayGainAlbumGain) : ""
    ))
    replayGainRows.append((
      "Album Peak",
      playable.replayGainAlbumPeak != 0
        ? String(format: "%.6f", playable.replayGainAlbumPeak) : ""
    ))

    addSection(title: "ReplayGain", rows: replayGainRows)

    // Download Section
    var downloadRows: [(String, String)] = []
    isUserDownloaded = playable.isCached
    downloadRows.append(("Downloaded", isUserDownloaded ? "Yes" : "No"))
    downloadRows.append((
      "Downloaded Format",
      isUserDownloaded
        ? (playable.contentTypeTranscoded ?? "") : ""
    ))

    addDownloadSection(rows: downloadRows, isDownloaded: isUserDownloaded)
  }

  private func addDownloadSection(rows: [(String, String)], isDownloaded: Bool) {
    // Section header
    let headerLabel = UILabel()
    headerLabel.text = "DOWNLOAD"
    headerLabel.font = .systemFont(ofSize: 12, weight: .medium)
    headerLabel.textColor = .secondaryLabel
    headerLabel.translatesAutoresizingMaskIntoConstraints = false

    let headerContainer = UIView()
    headerContainer.translatesAutoresizingMaskIntoConstraints = false
    headerContainer.addSubview(headerLabel)

    NSLayoutConstraint.activate([
      headerLabel.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 12),
      headerLabel.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -12),
      headerLabel.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: 8),
      headerLabel.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: -4),
    ])

    stackView.addArrangedSubview(headerContainer)

    // Section content container
    let sectionContainer = UIView()
    sectionContainer.backgroundColor = .clear
    sectionContainer.translatesAutoresizingMaskIntoConstraints = false

    let rowsStackView = UIStackView()
    rowsStackView.axis = .vertical
    rowsStackView.spacing = 0
    rowsStackView.translatesAutoresizingMaskIntoConstraints = false
    sectionContainer.addSubview(rowsStackView)

    NSLayoutConstraint.activate([
      rowsStackView.topAnchor.constraint(equalTo: sectionContainer.topAnchor),
      rowsStackView.leadingAnchor.constraint(equalTo: sectionContainer.leadingAnchor),
      rowsStackView.trailingAnchor.constraint(equalTo: sectionContainer.trailingAnchor),
      rowsStackView.bottomAnchor.constraint(equalTo: sectionContainer.bottomAnchor),
    ])

    // Add info rows
    for (index, row) in rows.enumerated() {
      let rowView = createRowView(label: row.0, value: row.1, isLast: false)
      rowsStackView.addArrangedSubview(rowView)
    }

    // Add download/delete button row
    let buttonRow = createDownloadButtonRow(isDownloaded: isDownloaded)
    rowsStackView.addArrangedSubview(buttonRow)

    stackView.addArrangedSubview(sectionContainer)
  }

  private func createDownloadButtonRow(isDownloaded: Bool) -> UIView {
    let container = UIView()
    container.translatesAutoresizingMaskIntoConstraints = false

    var config = UIButton.Configuration.plain()
    config.imagePadding = 8

    if isDownloaded {
      config.title = "Delete from Device"
      config.image = UIImage(systemName: "trash")
      config.baseForegroundColor = .systemRed
    } else {
      config.title = "Download to Device"
      config.image = UIImage(systemName: "arrow.down.circle")
      config.baseForegroundColor = .label
    }

    let button = UIButton(configuration: config)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.addTarget(self, action: #selector(downloadButtonTapped), for: .touchUpInside)

    container.addSubview(button)

    NSLayoutConstraint.activate([
      button.centerXAnchor.constraint(equalTo: container.centerXAnchor),
      button.centerYAnchor.constraint(equalTo: container.centerYAnchor),
      container.heightAnchor.constraint(equalToConstant: 50),
    ])

    return container
  }

  @objc
  private func downloadButtonTapped() {
    guard let playable = playable else { return }

    if isUserDownloaded {
      // Delete the cache file
      amperKit.storage.main.library.deleteCache(ofPlayable: playable)

      // Also delete the DownloadMO record
      if let song = playable.asSong, let downloadMO = song.managedObject.download {
        amperKit.storage.main.context.delete(downloadMO)
      }

      amperKit.storage.main.saveContext()

      showCopiedToast(message: "Removed from device")

      // Refresh the view
      refreshContent()
    } else {
      // User wants to download the song
      if playable.isCached {
        // Already cached
        showCopiedToast(message: "Already downloaded")
        refreshContent()
      } else {
        // Not cached yet, start download
        if let song = playable.asSong, let accountInfo = song.account?.info {
          amperKit.getMeta(accountInfo).playableDownloadManager.download(object: song)
          showCopiedToast(message: "Download started")
        }
      }
    }
  }

  private func refreshContent() {
    // Remove all arranged subviews
    for subview in stackView.arrangedSubviews {
      stackView.removeArrangedSubview(subview)
      subview.removeFromSuperview()
    }

    // Rebuild content
    buildMetadataContent()
  }

  private func addSection(title: String, rows: [(String, String)]) {
    // Section header
    let headerLabel = UILabel()
    headerLabel.text = title.uppercased()
    headerLabel.font = .systemFont(ofSize: 12, weight: .medium)
    headerLabel.textColor = .secondaryLabel
    headerLabel.translatesAutoresizingMaskIntoConstraints = false

    let headerContainer = UIView()
    headerContainer.translatesAutoresizingMaskIntoConstraints = false
    headerContainer.addSubview(headerLabel)

    NSLayoutConstraint.activate([
      headerLabel.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 12),
      headerLabel.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -12),
      headerLabel.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: 8),
      headerLabel.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: -4),
    ])

    stackView.addArrangedSubview(headerContainer)

    // Section content container
    let sectionContainer = UIView()
    sectionContainer.backgroundColor = .clear
    sectionContainer.translatesAutoresizingMaskIntoConstraints = false

    let rowsStackView = UIStackView()
    rowsStackView.axis = .vertical
    rowsStackView.spacing = 0
    rowsStackView.translatesAutoresizingMaskIntoConstraints = false
    sectionContainer.addSubview(rowsStackView)

    NSLayoutConstraint.activate([
      rowsStackView.topAnchor.constraint(equalTo: sectionContainer.topAnchor),
      rowsStackView.leadingAnchor.constraint(equalTo: sectionContainer.leadingAnchor),
      rowsStackView.trailingAnchor.constraint(equalTo: sectionContainer.trailingAnchor),
      rowsStackView.bottomAnchor.constraint(equalTo: sectionContainer.bottomAnchor),
    ])

    for (index, row) in rows.enumerated() {
      let rowView = createRowView(label: row.0, value: row.1, isLast: index == rows.count - 1)
      rowsStackView.addArrangedSubview(rowView)
    }

    stackView.addArrangedSubview(sectionContainer)
  }

  private func addStackedSection(title: String, rows: [(String, String)]) {
    // Section header
    let headerLabel = UILabel()
    headerLabel.text = title.uppercased()
    headerLabel.font = .systemFont(ofSize: 12, weight: .medium)
    headerLabel.textColor = .secondaryLabel
    headerLabel.translatesAutoresizingMaskIntoConstraints = false

    let headerContainer = UIView()
    headerContainer.translatesAutoresizingMaskIntoConstraints = false
    headerContainer.addSubview(headerLabel)

    NSLayoutConstraint.activate([
      headerLabel.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 12),
      headerLabel.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -12),
      headerLabel.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: 8),
      headerLabel.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: -4),
    ])

    stackView.addArrangedSubview(headerContainer)

    // Section content container
    let sectionContainer = UIView()
    sectionContainer.backgroundColor = .clear
    sectionContainer.translatesAutoresizingMaskIntoConstraints = false

    let rowsStackView = UIStackView()
    rowsStackView.axis = .vertical
    rowsStackView.spacing = 0
    rowsStackView.translatesAutoresizingMaskIntoConstraints = false
    sectionContainer.addSubview(rowsStackView)

    NSLayoutConstraint.activate([
      rowsStackView.topAnchor.constraint(equalTo: sectionContainer.topAnchor),
      rowsStackView.leadingAnchor.constraint(equalTo: sectionContainer.leadingAnchor),
      rowsStackView.trailingAnchor.constraint(equalTo: sectionContainer.trailingAnchor),
      rowsStackView.bottomAnchor.constraint(equalTo: sectionContainer.bottomAnchor),
    ])

    for (index, row) in rows.enumerated() {
      let rowView = createStackedRowView(
        label: row.0,
        value: row.1,
        isLast: index == rows.count - 1
      )
      rowsStackView.addArrangedSubview(rowView)
    }

    stackView.addArrangedSubview(sectionContainer)
  }

  private func createStackedRowView(label: String, value: String, isLast: Bool) -> UIView {
    let container = UIView()
    container.translatesAutoresizingMaskIntoConstraints = false

    let labelLabel = UILabel()
    labelLabel.text = label
    labelLabel.font = .systemFont(ofSize: 13, weight: .medium)
    labelLabel.textColor = .label
    labelLabel.translatesAutoresizingMaskIntoConstraints = false

    let valueLabel = UILabel()
    valueLabel.text = value
    valueLabel.font = .systemFont(ofSize: 14)
    valueLabel.textColor = .secondaryLabel
    valueLabel.numberOfLines = 0
    valueLabel.lineBreakMode = .byCharWrapping
    valueLabel.translatesAutoresizingMaskIntoConstraints = false

    container.addSubview(labelLabel)
    container.addSubview(valueLabel)

    let separator = UIView()
    separator.backgroundColor = .separator
    separator.translatesAutoresizingMaskIntoConstraints = false
    separator.isHidden = isLast
    container.addSubview(separator)

    NSLayoutConstraint.activate([
      labelLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
      labelLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
      labelLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

      valueLabel.topAnchor.constraint(equalTo: labelLabel.bottomAnchor, constant: 4),
      valueLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
      valueLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
      valueLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),

      separator.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
      separator.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      separator.bottomAnchor.constraint(equalTo: container.bottomAnchor),
      separator.heightAnchor.constraint(equalToConstant: 0.5),
    ])

    // Add tap gesture to copy value
    let tap = UITapGestureRecognizer(target: self, action: #selector(rowTapped(_:)))
    container.addGestureRecognizer(tap)
    container.isUserInteractionEnabled = true
    container.accessibilityLabel = value

    return container
  }

  private func createRowView(
    label: String,
    value: String,
    isLast: Bool,
    showCopyIcon: Bool = false
  )
    -> UIView {
    let container = UIView()
    container.translatesAutoresizingMaskIntoConstraints = false

    let labelLabel = UILabel()
    labelLabel.text = label
    labelLabel.font = .systemFont(ofSize: 15)
    labelLabel.textColor = .label
    labelLabel.translatesAutoresizingMaskIntoConstraints = false
    labelLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)

    let valueLabel = UILabel()
    valueLabel.text = value
    valueLabel.font = .systemFont(ofSize: 15)
    valueLabel.textColor = .secondaryLabel
    valueLabel.textAlignment = .right
    valueLabel.numberOfLines = 2
    valueLabel.lineBreakMode = .byTruncatingMiddle
    valueLabel.translatesAutoresizingMaskIntoConstraints = false

    container.addSubview(labelLabel)
    container.addSubview(valueLabel)

    // Add copy icon if requested
    var copyIcon: UIImageView?
    if showCopyIcon {
      let icon = UIImageView(image: UIImage(systemName: "doc.on.doc"))
      icon.tintColor = .secondaryLabel
      icon.translatesAutoresizingMaskIntoConstraints = false
      icon.contentMode = .scaleAspectFit
      container.addSubview(icon)
      copyIcon = icon
    }

    let separator = UIView()
    separator.backgroundColor = .separator
    separator.translatesAutoresizingMaskIntoConstraints = false
    separator.isHidden = isLast
    container.addSubview(separator)

    if let copyIcon = copyIcon {
      NSLayoutConstraint.activate([
        labelLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
        labelLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),

        copyIcon.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
        copyIcon.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        copyIcon.widthAnchor.constraint(equalToConstant: 18),
        copyIcon.heightAnchor.constraint(equalToConstant: 18),

        valueLabel.leadingAnchor.constraint(equalTo: labelLabel.trailingAnchor, constant: 8),
        valueLabel.trailingAnchor.constraint(equalTo: copyIcon.leadingAnchor, constant: -8),
        valueLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
      ])
    } else {
      NSLayoutConstraint.activate([
        labelLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
        labelLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),

        valueLabel.leadingAnchor.constraint(equalTo: labelLabel.trailingAnchor, constant: 8),
        valueLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
        valueLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
      ])
    }

    NSLayoutConstraint.activate([
      container.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),

      separator.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
      separator.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      separator.bottomAnchor.constraint(equalTo: container.bottomAnchor),
      separator.heightAnchor.constraint(equalToConstant: 0.5),
    ])

    // Add tap gesture to copy value
    let tap = UITapGestureRecognizer(target: self, action: #selector(rowTapped(_:)))
    container.addGestureRecognizer(tap)
    container.isUserInteractionEnabled = true
    container.accessibilityLabel = value

    return container
  }

  @objc
  private func rowTapped(_ gesture: UITapGestureRecognizer) {
    guard let view = gesture.view, let value = view.accessibilityLabel else { return }
    UIPasteboard.general.string = value

    let generator = UINotificationFeedbackGenerator()
    generator.notificationOccurred(.success)

    // Show toast notification
    showCopiedToast(message: "Copied to clipboard")
  }

  private func showCopiedToast(message: String = "Copied to clipboard") {
    let toast = UILabel()
    toast.text = message
    toast.font = .systemFont(ofSize: 14, weight: .medium)
    toast.textColor = UIColor { traitCollection in
      traitCollection.userInterfaceStyle == .dark ? .white : .black
    }
    toast.backgroundColor = UIColor { traitCollection in
      traitCollection.userInterfaceStyle == .dark
        ? UIColor.black.withAlphaComponent(0.75)
        : UIColor.white.withAlphaComponent(0.9)
    }
    toast.textAlignment = .center
    toast.layer.cornerRadius = 8
    toast.clipsToBounds = true
    toast.translatesAutoresizingMaskIntoConstraints = false
    toast.alpha = 0

    view.addSubview(toast)

    NSLayoutConstraint.activate([
      toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      toast.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
      toast.widthAnchor.constraint(greaterThanOrEqualToConstant: 150),
      toast.heightAnchor.constraint(equalToConstant: 36),
    ])

    // Add padding
    toast.layoutMargins = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)

    UIView.animate(withDuration: 0.2) {
      toast.alpha = 1
    } completion: { _ in
      UIView.animate(withDuration: 0.2, delay: 1.0) {
        toast.alpha = 0
      } completion: { _ in
        toast.removeFromSuperview()
      }
    }
  }
}

// MARK: UIPopoverPresentationControllerDelegate

extension SongMetadataVC: UIPopoverPresentationControllerDelegate {
  func adaptivePresentationStyle(
    for controller: UIPresentationController,
    traitCollection: UITraitCollection
  )
    -> UIModalPresentationStyle {
    .none // Keep popover style on iPhone too
  }
}
