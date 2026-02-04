//
//  LyricTableCell.swift
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
import CoreData
import UIKit

// MARK: - Apple Music Style Constants

private enum LyricsStyle {
  static let activeFontSize: CGFloat = 28
  static let inactiveFontSize: CGFloat = 28
  static let activeScale: CGFloat = 1.0
  static let inactiveScale: CGFloat = 1.0
  static let inactiveOpacity: CGFloat = 0.3
  static let animationDuration: TimeInterval = 0.7
}

// MARK: - LyricTableCellModel

@MainActor
class LyricTableCellModel {
  var lyric: LyricsLine? {
    didSet {
      cell?.refresh()
    }
  }

  var isActiveLine = false {
    didSet {
      if oldValue != isActiveLine {
        cell?.animateToState(isActive: isActiveLine)
      }
    }
  }

  private var attributedString: NSAttributedString?
  private var highlightedAttributedString: NSAttributedString?

  internal weak var cell: LyricTableCell?

  var displayString: NSAttributedString? {
    if isActiveLine {
      return highlightedAttributedString
    } else {
      return attributedString
    }
  }

  init(lyric: LyricsLine) {
    self.lyric = lyric
    self.isActiveLine = false
    self.attributedString = NSAttributedString(
      string: lyric.value,
      attributes:
      [
        .font: UIFont.systemFont(ofSize: LyricsStyle.inactiveFontSize, weight: .bold),
        .foregroundColor: UIColor.customDarkLabel.withAlphaComponent(LyricsStyle.inactiveOpacity),
      ]
    )
    self.highlightedAttributedString = NSAttributedString(
      string: lyric.value,
      attributes:
      [
        .font: UIFont.systemFont(ofSize: LyricsStyle.activeFontSize, weight: .bold),
        .foregroundColor: UIColor.customDarkLabel,
      ]
    )
  }

  public func calcHeight(containerWidth: CGFloat) -> CGFloat {
    let boundingSize = CGSize(
      width: LyricTableCell.adjustContainerWidthForMargins(containerWidth: containerWidth),
      height: 9_999
    )
    return highlightedAttributedString?.boundingRect(
      with: boundingSize,
      options: .usesLineFragmentOrigin,
      context: nil
    ).height ?? 0
  }
}

// MARK: - LyricTableCell

class LyricTableCell: UITableViewCell {
  private weak var viewModel: LyricTableCellModel? = nil

  private var lyricLabel: UILabel!
  override var layoutMargins: UIEdgeInsets { get { BasicTableCell.margin } set {} }

  static func adjustContainerWidthForMargins(containerWidth: CGFloat) -> CGFloat {
    containerWidth - (2 * BasicTableCell.margin.right)
  }

  public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    commonInit()
  }

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    commonInit()
  }

  private func commonInit() {
    lyricLabel = UILabel(frame: CGRect(
      x: layoutMargins.left,
      y: 0,
      width: bounds.width - (2 * layoutMargins.right),
      height: bounds.height
    ))
    lyricLabel.textAlignment = .center
    lyricLabel.lineBreakMode = .byWordWrapping
    lyricLabel.numberOfLines = 0
    selectionStyle = .none
    contentView.addSubview(lyricLabel)
    backgroundColor = .clear
    
    // Start with inactive scale
    lyricLabel.transform = CGAffineTransform(scaleX: LyricsStyle.inactiveScale, y: LyricsStyle.inactiveScale)
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    lyricLabel.frame = CGRect(
      x: layoutMargins.left,
      y: 0,
      width: bounds.width - (2 * layoutMargins.right),
      height: bounds.height
    )
  }

  func display(model: LyricTableCellModel) {
    viewModel = model
    model.cell = self
    refresh()
    
    // Set initial state without animation
    if model.isActiveLine {
      lyricLabel.transform = .identity
    } else {
      lyricLabel.transform = CGAffineTransform(scaleX: LyricsStyle.inactiveScale, y: LyricsStyle.inactiveScale)
    }
  }

  func refresh() {
    guard let model = viewModel else { return }
    lyricLabel.attributedText = model.displayString
  }
  
  func animateToState(isActive: Bool) {
    guard let model = viewModel else { return }
    
    // Animate scale
    UIView.animate(
      withDuration: LyricsStyle.animationDuration,
      delay: 0,
      options: [.curveEaseInOut, .allowUserInteraction],
      animations: {
        if isActive {
          self.lyricLabel.transform = .identity
        } else {
          self.lyricLabel.transform = CGAffineTransform(
            scaleX: LyricsStyle.inactiveScale,
            y: LyricsStyle.inactiveScale
          )
        }
      },
      completion: nil
    )
    
    // Crossfade the text change
    UIView.transition(
      with: lyricLabel,
      duration: LyricsStyle.animationDuration,
      options: [.transitionCrossDissolve, .allowUserInteraction],
      animations: {
        self.lyricLabel.attributedText = model.displayString
      },
      completion: nil
    )
  }
}

// MARK: - InterludeIndicatorCell

class InterludeIndicatorCell: UITableViewCell {
  static let reuseIdentifier = "InterludeIndicatorCell"
  
  private var dot1: UIView!
  private var dot2: UIView!
  private var dot3: UIView!
  private var isAnimating = false
  
  private let dotSize: CGFloat = 14
  private let dotSpacing: CGFloat = 16
  
  public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    commonInit()
  }
  
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    commonInit()
  }
  
  private func commonInit() {
    selectionStyle = .none
    backgroundColor = .clear
    
    // Create the three dots
    dot1 = createDot()
    dot2 = createDot()
    dot3 = createDot()
    
    // Start hidden until animation starts
    dot1.alpha = 0.0
    dot2.alpha = 0.0
    dot3.alpha = 0.0
    
    contentView.addSubview(dot1)
    contentView.addSubview(dot2)
    contentView.addSubview(dot3)
  }
  
  private func createDot() -> UIView {
    let dot = UIView()
    dot.backgroundColor = UIColor.customDarkLabel
    dot.layer.cornerRadius = dotSize / 2
    dot.translatesAutoresizingMaskIntoConstraints = false
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
    
    // Fade in dots
    UIView.animate(withDuration: 0.3) {
      self.dot1.alpha = 1.0
      self.dot2.alpha = 1.0
      self.dot3.alpha = 1.0
    }
    
    animateDots()
  }
  
  func stopAnimating() {
    isAnimating = false
    dot1.layer.removeAllAnimations()
    dot2.layer.removeAllAnimations()
    dot3.layer.removeAllAnimations()
    
    // Reset transforms and hide
    dot1.transform = .identity
    dot2.transform = .identity
    dot3.transform = .identity
    
    UIView.animate(withDuration: 0.2) {
      self.dot1.alpha = 0.0
      self.dot2.alpha = 0.0
      self.dot3.alpha = 0.0
    }
  }
  
  override func prepareForReuse() {
    super.prepareForReuse()
    stopAnimating()
  }
  
  private func animateDots() {
    guard isAnimating else { return }
    
    let duration: TimeInterval = 0.3
    let delay: TimeInterval = 0.1
    let scaleUp: CGFloat = 1.4
    
    // Combined transform: translate up and scale up
    let upTransform = CGAffineTransform(translationX: 0, y: -12).scaledBy(x: scaleUp, y: scaleUp)
    
    // Animate dot 1
    UIView.animate(
      withDuration: duration,
      delay: 0,
      options: [.curveEaseInOut],
      animations: {
        self.dot1.transform = upTransform
      }
    ) { _ in
      UIView.animate(
        withDuration: duration,
        delay: 0,
        options: [.curveEaseInOut],
        animations: {
          self.dot1.transform = .identity
        }
      )
    }
    
    // Animate dot 2 with delay
    UIView.animate(
      withDuration: duration,
      delay: delay,
      options: [.curveEaseInOut],
      animations: {
        self.dot2.transform = upTransform
      }
    ) { _ in
      UIView.animate(
        withDuration: duration,
        delay: 0,
        options: [.curveEaseInOut],
        animations: {
          self.dot2.transform = .identity
        }
      )
    }
    
    // Animate dot 3 with more delay
    UIView.animate(
      withDuration: duration,
      delay: delay * 2,
      options: [.curveEaseInOut],
      animations: {
        self.dot3.transform = upTransform
      }
    ) { _ in
      UIView.animate(
        withDuration: duration,
        delay: 0,
        options: [.curveEaseInOut],
        animations: {
          self.dot3.transform = .identity
        }
      ) { _ in
        // Repeat the animation after a short pause
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
          self.animateDots()
        }
      }
    }
  }
}
