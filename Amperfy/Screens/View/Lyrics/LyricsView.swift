//
//  LyricsView.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 17.06.24.
//  Copyright (c) 2021 Maximilian Bauer. All rights reserved.
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
import CoreMedia
import Foundation
import UIKit

class LyricsView: UITableView, UITableViewDataSource, UITableViewDelegate {
  private var lyrics: StructuredLyrics? = nil
  private var lyricModels: [LyricTableCellModel] = []
  private var lastIndex: Int?
  private var lineSpacing: CGFloat = 16
  private var hasLastLyricsLineAlreadyDisplayedOnce = false
  private var scrollAnimation = true

  override init(frame: CGRect, style: UITableView.Style) {
    super.init(frame: frame, style: style)
    commonInit()
  }

  public required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    commonInit()
  }

  private func commonInit() {
    register(LyricTableCell.self, forCellReuseIdentifier: LyricTableCell.typeName)

    separatorStyle = .none
    clipsToBounds = true

    dataSource = self
    delegate = self

    backgroundColor = .clear
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    reloadInsets()

    layer.mask = visibilityMask()
    layer.masksToBounds = true
  }

  private func visibilityMask() -> CAGradientLayer {
    let mask = CAGradientLayer()
    mask.frame = bounds
    mask.colors = [
      UIColor.white.withAlphaComponent(0).cgColor,
      UIColor.white.cgColor,
      UIColor.white.cgColor,
      UIColor.white.withAlphaComponent(0).cgColor,
    ]
    mask.locations = [0, 0.2, 0.8, 1]
    return mask
  }

  public func display(lyrics: StructuredLyrics, scrollAnimation: Bool) {
    self.lyrics = lyrics
    self.scrollAnimation = scrollAnimation
    reloadViewModels()
  }

  public func highlightAllLyrics() {
    lyricModels.forEach { $0.isActiveLine = true }
  }

  public func clear() {
    lyrics = nil
    reloadViewModels()
  }

  public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    lyricModels.count
  }

  public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    guard let model = lyricModels.object(at: indexPath.row) else { return 0.0 }
    return lineSpacing + model.calcHeight(containerWidth: bounds.width)
  }

  public func tableView(
    _ tableView: UITableView,
    estimatedHeightForRowAt indexPath: IndexPath
  )
    -> CGFloat {
    guard let model = lyricModels.object(at: indexPath.row) else { return 0.0 }
    return lineSpacing + model.calcHeight(containerWidth: bounds.width)
  }

  public func tableView(
    _ tableView: UITableView,
    cellForRowAt indexPath: IndexPath
  )
    -> UITableViewCell {
    let cell = dequeueReusableCell(
      withIdentifier: LyricTableCell.typeName,
      for: indexPath
    ) as! LyricTableCell
    if let model = lyricModels.object(at: indexPath.row) {
      cell.display(model: model)
    }
    return cell
  }

  public func tableView(
    _ tableView: UITableView,
    shouldHighlightRowAt indexPath: IndexPath
  )
    -> Bool {
    false
  }

  private func reloadViewModels() {
    lyricModels.removeAll()
    lastIndex = nil
    hasLastLyricsLineAlreadyDisplayedOnce = false
    reloadInsets()

    guard let lyrics = lyrics else {
      reloadData()
      return
    }

    for lyric in lyrics.line {
      let model = LyricTableCellModel(lyric: lyric)
      lyricModels.append(model)
    }
    reloadData()
  }

  func reloadInsets() {
    contentInset = UIEdgeInsets(
      top: frame.height / 2,
      left: 0,
      bottom: frame.height / 2,
      right: 0
    )
  }

  func scroll(toTime time: CMTime) {
    guard let lyrics = lyrics,
          !lyricModels.isEmpty,
          lyrics.synced // if the lyrics are not synced -> only display
    else { return }

    guard let indexOfNextLine = lyrics.line.firstIndex(where: { $0.startTime >= time }) else {
      if !hasLastLyricsLineAlreadyDisplayedOnce {
        scrollToRow(
          at: IndexPath(row: lyricModels.count - 1, section: 0),
          at: .middle,
          animated: scrollAnimation
        )
        hasLastLyricsLineAlreadyDisplayedOnce = true
      }
      if let lastIndex = lastIndex,
         let lastIndexModel = lyricModels.object(at: lastIndex) {
        lastIndexModel.isActiveLine = false
        reconfigureRows(at: [IndexPath(row: lastIndex, section: 0)])
      }
      lastIndex = nil
      return
    }

    var prevIndex: Int?
    hasLastLyricsLineAlreadyDisplayedOnce = false
    let indexOfCurrentLine = max(indexOfNextLine - 1, 0)
    if let lastIndex = lastIndex,
       let lastIndexModel = lyricModels.object(at: lastIndex) {
      lastIndexModel.isActiveLine = false
      prevIndex = lastIndex
    }
    lastIndex = indexOfCurrentLine
    let curIndexModel = lyricModels.object(at: indexOfCurrentLine)
    curIndexModel?.isActiveLine = true

    if prevIndex != indexOfCurrentLine {
      if curIndexModel != nil {
        reconfigureRows(at: [IndexPath(row: indexOfCurrentLine, section: 0)])
      }
      if let prevIndex = prevIndex, lyricModels.object(at: prevIndex) != nil {
        reconfigureRows(at: [IndexPath(row: prevIndex, section: 0)])
      }
    }
    scrollToRow(
      at: IndexPath(row: indexOfCurrentLine, section: 0),
      at: .middle,
      animated: scrollAnimation
    )
  }
}
