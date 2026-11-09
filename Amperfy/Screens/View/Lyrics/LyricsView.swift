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
import os.log
import UIKit

class LyricsView: UITableView, UITableViewDataSource, UITableViewDelegate {
  private var lyrics: StructuredLyrics? = nil
  private var lyricModels: [LyricTableCellModel] = []
  private var lastIndex: Int?
  private var lineSpacing: CGFloat = 16
  private var hasLastLyricsLineAlreadyDisplayedOnce = false
  private var scrollAnimation = true
  private var isWordHighlightEnabled = true
  private var hasWordTiming = false
  private var lastLineEnd: Int?
  private var scrolledToIndex: Int?
  private var suppressAutoScrollUntil: Date?
  private let autoScrollSuppressionInterval: TimeInterval = 5.0
  private let visibilityMaskLayer = CAGradientLayer()
  private var wordTimingDisplayLink: CADisplayLink?
  private var playbackClock = LyricsPlaybackClock()

  private let log = OSLog(subsystem: "Amperfy", category: "LyricsView")

  /// Called with the playback time in seconds of the selected line
  public var onLyricSelected: ((TimeInterval) -> ())?
  /// The playback time in seconds, the playback rate and whether the player plays.
  /// With it, sung words are filled smoothly for each display frame.
  public var playbackStateProvider: (() -> (time: TimeInterval, rate: Double, isPlaying: Bool))?

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
    allowsSelection = true

    backgroundColor = .clear

    visibilityMaskLayer.colors = [
      UIColor.white.withAlphaComponent(0).cgColor,
      UIColor.white.cgColor,
      UIColor.white.cgColor,
      UIColor.white.withAlphaComponent(0).cgColor,
    ]
    visibilityMaskLayer.locations = [0, 0.2, 0.8, 1]
    layer.mask = visibilityMaskLayer
    layer.masksToBounds = true
  }

  // called for each frame while the table scrolls: keep the work small
  override func layoutSubviews() {
    super.layoutSubviews()
    if contentInset.top != frame.height / 2 {
      reloadInsets()
      scrolledToIndex = nil
    }
    // the bounds move with the scroll position, the mask must stay in place
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    visibilityMaskLayer.frame = bounds
    CATransaction.commit()
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    if window == nil {
      stopWordTiming()
    }
  }

  public func display(lyrics: StructuredLyrics, scrollAnimation: Bool, wordHighlight: Bool) {
    self.lyrics = lyrics
    self.scrollAnimation = scrollAnimation
    isWordHighlightEnabled = wordHighlight
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
    guard lyrics?.synced == true,
          let model = lyricModels.object(at: indexPath.row),
          model.lyric?.start != nil
    else { return false }
    return true
  }

  public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    guard let lyrics, lyrics.synced,
          let model = lyricModels.object(at: indexPath.row),
          let lyric = model.lyric,
          lyric.start != nil
    else { return }
    suppressAutoScrollUntil = Date().addingTimeInterval(autoScrollSuppressionInterval)
    onLyricSelected?(lyrics.playbackSeconds(of: lyric))
  }

  public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
    suppressAutoScrollUntil = Date().addingTimeInterval(autoScrollSuppressionInterval)
    scrolledToIndex = nil
  }

  public func scrollViewDidEndDragging(
    _ scrollView: UIScrollView,
    willDecelerate decelerate: Bool
  ) {
    if !decelerate {
      suppressAutoScrollUntil = Date().addingTimeInterval(autoScrollSuppressionInterval)
    }
  }

  public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
    suppressAutoScrollUntil = Date().addingTimeInterval(autoScrollSuppressionInterval)
  }

  private func reloadViewModels() {
    stopWordTiming()
    lyricModels.removeAll()
    lastIndex = nil
    scrolledToIndex = nil
    hasWordTiming = false
    hasLastLyricsLineAlreadyDisplayedOnce = false
    reloadInsets()

    guard let lyrics = lyrics else {
      lastLineEnd = nil
      reloadData()
      return
    }

    lastLineEnd = lyrics.lastLineEnd
    let isWordHighlight = isWordHighlightEnabled && lyrics.synced && !lyrics.cueLines.isEmpty
    var lineCountWithoutWordTiming = 0
    for (index, lyric) in lyrics.line.enumerated() {
      let cueLine = isWordHighlight ? lyrics.mainCueLine(forLine: index) : nil
      let model = LyricTableCellModel(lyric: lyric, cueLine: cueLine)
      if cueLine != nil, model.cueLine == nil {
        lineCountWithoutWordTiming += 1
      }
      lyricModels.append(model)
    }
    hasWordTiming = lyricModels.contains { $0.cueLine != nil }
    if lineCountWithoutWordTiming > 0 {
      os_log(
        "Word timing does not match the text of %d lines: line highlight only",
        log: log,
        type: .debug,
        lineCountWithoutWordTiming
      )
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

  /// Called by the player about 10 times a second while it plays
  func scroll(toTime time: CMTime) {
    guard window != nil, !isHidden, // no work at 10 Hz for lyrics that cannot be seen
          let lyrics = lyrics,
          !lyricModels.isEmpty,
          lyrics.synced // if the lyrics are not synced -> only display
    else { return }
    // the display link gives a smoother time while it runs
    guard wordTimingDisplayLink == nil else { return }
    update(lyricsTime: lyrics.lyricsTime(at: time))
    startWordTimingIfNeeded()
  }

  private func startWordTimingIfNeeded() {
    guard hasWordTiming, playbackStateProvider != nil, wordTimingDisplayLink == nil else { return }
    playbackClock.reset()
    let displayLink = CADisplayLink(target: self, selector: #selector(wordTimingDidFire(_:)))
    displayLink.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
    displayLink.add(to: .main, forMode: .common)
    wordTimingDisplayLink = displayLink
  }

  private func stopWordTiming() {
    wordTimingDisplayLink?.invalidate()
    wordTimingDisplayLink = nil
  }

  @objc
  private func wordTimingDidFire(_ displayLink: CADisplayLink) {
    guard window != nil, !isHidden, let lyrics, lyrics.synced,
          let state = playbackStateProvider?(), state.isPlaying
    else {
      stopWordTiming()
      return
    }
    let seconds = playbackClock.time(
      playerTime: state.time,
      rate: state.rate,
      hostTime: displayLink.timestamp
    )
    update(lyricsTime: lyrics.lyricsTime(atSeconds: seconds))
  }

  private func update(lyricsTime: Int) {
    guard let lyrics, !lyricModels.isEmpty else { return }
    let isAutoScrollAllowed: Bool = {
      guard let suppressUntil = suppressAutoScrollUntil else { return true }
      return Date() >= suppressUntil
    }()

    // the last line stays active until its end, if the lyrics give it
    let isLastLineActive = lastLineEnd.map { lyricsTime <= $0 } ?? false
    guard let indexOfNextLine = lyrics.line.firstIndex(where: { ($0.start ?? 0) > lyricsTime })
      ?? (isLastLineActive ? lyrics.line.count : nil) else {
      if !hasLastLyricsLineAlreadyDisplayedOnce {
        if isAutoScrollAllowed {
          scrollToRow(
            at: IndexPath(row: lyricModels.count - 1, section: 0),
            at: .middle,
            animated: scrollAnimation
          )
          hasLastLyricsLineAlreadyDisplayedOnce = true
        }
      }
      if let lastIndex = lastIndex,
         let lastIndexModel = lyricModels.object(at: lastIndex) {
        lastIndexModel.isActiveLine = false
        lastIndexModel.wordProgress = nil
        reconfigureRows(at: [IndexPath(row: lastIndex, section: 0)])
      }
      lastIndex = nil
      scrolledToIndex = nil
      return
    }

    var prevIndex: Int?
    hasLastLyricsLineAlreadyDisplayedOnce = false
    let indexOfCurrentLine = max(indexOfNextLine - 1, 0)
    if let lastIndex = lastIndex,
       let lastIndexModel = lyricModels.object(at: lastIndex) {
      if lastIndex != indexOfCurrentLine {
        lastIndexModel.isActiveLine = false
        lastIndexModel.wordProgress = nil
      }
      prevIndex = lastIndex
    }
    lastIndex = indexOfCurrentLine
    let curIndexModel = lyricModels.object(at: indexOfCurrentLine)
    if curIndexModel?.isActiveLine == false {
      curIndexModel?.isActiveLine = true
    }
    // only the mask of the sung words in the active line changes
    curIndexModel?.wordProgress = curIndexModel?.cueLine?.progress(at: lyricsTime)

    if prevIndex != indexOfCurrentLine {
      if curIndexModel != nil {
        reconfigureRows(at: [IndexPath(row: indexOfCurrentLine, section: 0)])
      }
      if let prevIndex = prevIndex, lyricModels.object(at: prevIndex) != nil {
        reconfigureRows(at: [IndexPath(row: prevIndex, section: 0)])
      }
    }
    // scroll once for each line: a new call would restart the running scroll animation
    if isAutoScrollAllowed, scrolledToIndex != indexOfCurrentLine {
      scrollToRow(
        at: IndexPath(row: indexOfCurrentLine, section: 0),
        at: .middle,
        animated: scrollAnimation
      )
      scrolledToIndex = indexOfCurrentLine
    }
  }
}
