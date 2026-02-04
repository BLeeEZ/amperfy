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
  private var lineSpacing: CGFloat = 20
  private var hasLastLyricsLineAlreadyDisplayedOnce = false
  private var scrollAnimation = true
  private var isFirstScroll = true
  private var isUnsyncedLyrics = false
  
  // Interlude overlay
  private var interludeOverlay: InterludeOverlayView?
  private var isShowingInterlude = false
  private static let interludeGapThreshold: TimeInterval = 3.0

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
    
    // Create interlude overlay as table header so it scrolls with content
    interludeOverlay = InterludeOverlayView()
    interludeOverlay?.alpha = 0
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
    mask.locations = [0, 0.15, 0.85, 1]
    return mask
  }

  public func display(lyrics: StructuredLyrics, scrollAnimation: Bool) {
    self.lyrics = lyrics
    self.scrollAnimation = scrollAnimation
    self.isUnsyncedLyrics = !lyrics.synced
    
    // Reset interlude state
    isShowingInterlude = false
    isFadingOut = false
    interludeOverlay?.alpha = 0.0
    interludeOverlay?.stopAnimating()
    
    // Add overlay directly to table (scrolls with content)
    if let overlay = interludeOverlay {
      overlay.removeFromSuperview()
      addSubview(overlay)
    }
    
    // For static lyrics, disable all automatic scroll adjustments
    if isUnsyncedLyrics {
      UIView.performWithoutAnimation {
        self.reloadViewModels()
        self.positionInterludeOverlay()
        self.layoutIfNeeded()
        self.contentOffset = CGPoint(x: 0, y: -self.contentInset.top)
      }
    } else {
      reloadViewModels()
      positionInterludeOverlay()
      layoutIfNeeded()
      DispatchQueue.main.async {
        self.setContentOffset(CGPoint(x: 0, y: -self.contentInset.top), animated: false)
      }
    }
  }
  
  private func positionInterludeOverlay() {
    guard let overlay = interludeOverlay else { return }
    let overlayWidth: CGFloat = bounds.width
    let overlayHeight: CGFloat = 60
    // Position higher in the visible area to increase distance from first lyric line
    let yPosition = -contentInset.top + (frame.height - overlayHeight) / 2 - 40
    overlay.frame = CGRect(x: 0, y: yPosition, width: overlayWidth, height: overlayHeight)
  }

  public func highlightAllLyrics() {
    lyricModels.forEach { $0.isActiveLine = true }
  }

  public func clear() {
    lyrics = nil
    hideInterludeInstantly()
    interludeOverlay?.removeFromSuperview()
    reloadViewModels()
    
    // Reset scroll position
    setContentOffset(CGPoint(x: 0, y: -contentInset.top), animated: false)
  }
  
  /// Call this when music is paused to hide the interlude animation
  public func onPause() {
    hideInterludeInstantly()
  }
  
  /// Call this when music resumes to potentially show the interlude animation again
  public func onResume(atTime time: CMTime) {
    scroll(toTime: time)
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
    isFirstScroll = true
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
    positionInterludeOverlay()
  }

  func scroll(toTime time: CMTime) {
    guard let lyrics = lyrics,
          !lyricModels.isEmpty,
          lyrics.synced
    else { return }

    let shouldAnimate = isFirstScroll ? false : scrollAnimation
    if isFirstScroll {
      isFirstScroll = false
    }
    
    let currentTimeSeconds = CMTimeGetSeconds(time)
    
    // Check for intro (before first lyric) - only place we show interlude
    let firstLineStart = CMTimeGetSeconds(lyrics.line[0].startTime)
    
    // Timing for interlude fade out - start fading 0.8 seconds before first lyric
    let fadeOutStartTime = firstLineStart - 0.8
    
    if currentTimeSeconds < firstLineStart {
      // Show interlude during intro if:
      // 1. There's enough time before first lyric (>= 3 seconds)
      // 2. We're at least 0.5 seconds into the song
      // 3. We haven't started fading out yet
      if firstLineStart >= Self.interludeGapThreshold && 
         currentTimeSeconds >= 0.5 && 
         currentTimeSeconds < fadeOutStartTime {
        showInterlude()
      } else if currentTimeSeconds >= fadeOutStartTime {
        // Start fading out before lyrics begin
        fadeOutInterlude()
      } else {
        hideInterludeInstantly()
      }
      
      // Don't highlight any lyric during intro
      if let lastIndex = lastIndex, let lastIndexModel = lyricModels.object(at: lastIndex) {
        lastIndexModel.isActiveLine = false
        reloadRows(at: [IndexPath(row: lastIndex, section: 0)], with: .none)
      }
      lastIndex = nil
      return
    }
    
    // Past the intro - ensure interlude is hidden
    hideInterludeInstantly()

    guard let indexOfNextLine = lyrics.line.firstIndex(where: { $0.startTime >= time }) else {
      // Past all lyrics - highlight the last line
      let lastLineIndex = lyricModels.count - 1
      
      if !hasLastLyricsLineAlreadyDisplayedOnce {
        scrollToRow(
          at: IndexPath(row: lastLineIndex, section: 0),
          at: .middle,
          animated: shouldAnimate
        )
        hasLastLyricsLineAlreadyDisplayedOnce = true
      }
      
      // Deactivate previous line if different from last line
      if let prevIndex = lastIndex, prevIndex != lastLineIndex,
         let prevModel = lyricModels.object(at: prevIndex) {
        prevModel.isActiveLine = false
        reloadRows(at: [IndexPath(row: prevIndex, section: 0)], with: .none)
      }
      
      // Activate the last line
      if let lastLineModel = lyricModels.object(at: lastLineIndex) {
        lastLineModel.isActiveLine = true
        if lastIndex != lastLineIndex {
          reloadRows(at: [IndexPath(row: lastLineIndex, section: 0)], with: .none)
        }
      }
      lastIndex = lastLineIndex
      return
    }

    hasLastLyricsLineAlreadyDisplayedOnce = false
    let indexOfCurrentLine = max(indexOfNextLine - 1, 0)
    
    var prevIndex: Int?
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
        reloadRows(at: [IndexPath(row: indexOfCurrentLine, section: 0)], with: .none)
      }
      if let prevIndex = prevIndex, lyricModels.object(at: prevIndex) != nil {
        reloadRows(at: [IndexPath(row: prevIndex, section: 0)], with: .none)
      }
    }
    scrollToRow(
      at: IndexPath(row: indexOfCurrentLine, section: 0),
      at: .middle,
      animated: shouldAnimate
    )
  }
  
  private func showInterlude() {
    guard !isShowingInterlude else { return }
    isShowingInterlude = true
    isFadingOut = false
    
    interludeOverlay?.startAnimating()
    
    // Fade in
    UIView.animate(withDuration: 0.5) {
      self.interludeOverlay?.alpha = 1.0
    }
  }
  
  private var isFadingOut = false
  
  private func fadeOutInterlude() {
    guard isShowingInterlude, !isFadingOut else { return }
    isFadingOut = true
    
    // Fade out smoothly
    UIView.animate(withDuration: 0.6) {
      self.interludeOverlay?.alpha = 0.0
    } completion: { _ in
      self.interludeOverlay?.stopAnimating()
      self.isShowingInterlude = false
    }
  }
  
  private func hideInterludeInstantly() {
    isShowingInterlude = false
    isFadingOut = false
    
    // Stop animation and hide immediately
    interludeOverlay?.stopAnimating()
    interludeOverlay?.alpha = 0.0
  }
}

// MARK: - Interlude Overlay View

private class InterludeOverlayView: UIView {
  private var dot1: UIView!
  private var dot2: UIView!
  private var dot3: UIView!
  private var isAnimating = false
  
  private let dotSize: CGFloat = 14
  private let dotSpacing: CGFloat = 16
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    commonInit()
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    commonInit()
  }
  
  private func commonInit() {
    backgroundColor = .clear
    
    dot1 = createDot()
    dot2 = createDot()
    dot3 = createDot()
    
    addSubview(dot1)
    addSubview(dot2)
    addSubview(dot3)
  }
  
  private func createDot() -> UIView {
    let dot = UIView()
    dot.backgroundColor = UIColor.customDarkLabel
    dot.layer.cornerRadius = dotSize / 2
    return dot
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    let totalWidth = (dotSize * 3) + (dotSpacing * 2)
    let startX = (bounds.width - totalWidth) / 2
    let centerY = bounds.height / 2
    
    dot1.frame = CGRect(x: startX, y: centerY - dotSize/2, width: dotSize, height: dotSize)
    dot2.frame = CGRect(x: startX + dotSize + dotSpacing, y: centerY - dotSize/2, width: dotSize, height: dotSize)
    dot3.frame = CGRect(x: startX + (dotSize + dotSpacing) * 2, y: centerY - dotSize/2, width: dotSize, height: dotSize)
  }
  
  func startAnimating() {
    guard !isAnimating else { return }
    isAnimating = true
    
    // Use Core Animation for smooth, hardware-accelerated animation
    addPulseAnimation(to: dot1, delay: 0)
    addPulseAnimation(to: dot2, delay: 0.2)
    addPulseAnimation(to: dot3, delay: 0.4)
  }
  
  func stopAnimating() {
    isAnimating = false
    dot1.layer.removeAllAnimations()
    dot2.layer.removeAllAnimations()
    dot3.layer.removeAllAnimations()
    dot1.transform = .identity
    dot2.transform = .identity
    dot3.transform = .identity
  }
  
  private func addPulseAnimation(to dot: UIView, delay: CFTimeInterval) {
    // Scale animation
    let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
    scaleAnimation.fromValue = 1.0
    scaleAnimation.toValue = 1.4
    scaleAnimation.autoreverses = true
    scaleAnimation.duration = 0.6
    scaleAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
    
    // Bounce animation
    let bounceAnimation = CABasicAnimation(keyPath: "transform.translation.y")
    bounceAnimation.fromValue = 0
    bounceAnimation.toValue = -8
    bounceAnimation.autoreverses = true
    bounceAnimation.duration = 0.6
    bounceAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
    
    // Group both animations
    let group = CAAnimationGroup()
    group.animations = [scaleAnimation, bounceAnimation]
    group.duration = 1.6  // Full cycle with pause
    group.repeatCount = .infinity
    group.beginTime = CACurrentMediaTime() + delay
    
    dot.layer.add(group, forKey: "pulse")
  }
}
