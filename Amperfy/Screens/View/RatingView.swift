//
//  RatingView.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 21.01.26.
//  Copyright (c) 2026 Maximilian Bauer. All rights reserved.
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

// MARK: - RatingViewDelegate

@MainActor
protocol RatingViewDelegate: AnyObject {
  func ratingView(_ ratingView: RatingView, didChangeRating rating: Int)
  func ratingView(_ ratingView: RatingView, didToggleFavorite isFavorite: Bool)
}

// MARK: - RatingView

class RatingView: UIView {
  // MARK: - Properties

  weak var delegate: RatingViewDelegate?

  private var starImageViews: [UIImageView] = []
  private var heartImageView: UIImageView!
  private var stackView: UIStackView!
  private let starCount = 5
  private let starSize: CGFloat = 25
  private let starSpacing: CGFloat = 4
  private let heartSpacing: CGFloat = 16  // More spacing before heart
  
  private(set) var isFavorite: Bool = false {
    didSet {
      updateHeartDisplay()
    }
  }

  /// Star color for selected stars - adapts to light/dark mode
  private static var selectedStarColor: UIColor {
    UIColor { traitCollection in
      if traitCollection.userInterfaceStyle == .light {
        return .black
      } else {
        return UIColor(white: 0.9, alpha: 1.0)
      }
    }
  }

  /// Star color for unselected stars - adapts to light/dark mode
  private static var unselectedStarColor: UIColor {
    UIColor { traitCollection in
      if traitCollection.userInterfaceStyle == .light {
        return UIColor(white: 0.0, alpha: 0.2)  // Black with 2 0% opacity
      } else {
        return UIColor(white: 1.0, alpha: 0.1)  // White with 10% opacity
      }
    }
  }

  /// Whether the rating view is enabled for interaction
  /// When disabled, opacity is reduced to 50% and touches are ignored
  var isRatingEnabled: Bool = true {
    didSet {
      updateEnabledState()
    }
  }

  private(set) var rating: Int = 0 {
    didSet {
      updateStarDisplay()
    }
  }

  // MARK: - Initialization

  override init(frame: CGRect) {
    super.init(frame: frame)
    setupView()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setupView()
  }

  // MARK: - Setup

  private func setupView() {
    // Ensure touches can be received
    isUserInteractionEnabled = true
    clipsToBounds = false
    
    stackView = UIStackView()
    stackView.axis = .horizontal
    stackView.spacing = starSpacing
    stackView.alignment = .center
    stackView.distribution = .equalSpacing
    stackView.translatesAutoresizingMaskIntoConstraints = false
    stackView.isUserInteractionEnabled = true
    stackView.clipsToBounds = false

    addSubview(stackView)

    NSLayoutConstraint.activate([
      stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
      stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
      stackView.topAnchor.constraint(greaterThanOrEqualTo: topAnchor),
      stackView.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor),
      stackView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
      stackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
    ])

    // Create star image views
    for i in 0 ..< starCount {
      let starView = UIImageView()
      starView.tag = i + 1 // Tags 1-5 represent star ratings
      starView.contentMode = .scaleAspectFit
      starView.translatesAutoresizingMaskIntoConstraints = false
      starView.isUserInteractionEnabled = true
      
      // Set the filled star image with pre-baked color (unselected grey)
      let config = UIImage.SymbolConfiguration(pointSize: starSize, weight: .regular)
      let baseImage = UIImage.starFill.withConfiguration(config)
      starView.image = baseImage.withTintColor(Self.unselectedStarColor, renderingMode: .alwaysOriginal)

      NSLayoutConstraint.activate([
        starView.widthAnchor.constraint(equalToConstant: starSize + 8),  // Add padding for tap area
        starView.heightAnchor.constraint(equalToConstant: starSize + 8),
      ])

      // Add tap gesture
      let tap = UITapGestureRecognizer(target: self, action: #selector(starTapped(_:)))
      starView.addGestureRecognizer(tap)

      // Add long press to clear rating
      let longPress = UILongPressGestureRecognizer(target: self, action: #selector(starLongPressed(_:)))
      longPress.minimumPressDuration = 0.5
      starView.addGestureRecognizer(longPress)

      starImageViews.append(starView)
      stackView.addArrangedSubview(starView)
    }
    
    // Add spacer view for extra spacing before heart
    let spacerView = UIView()
    spacerView.translatesAutoresizingMaskIntoConstraints = false
    spacerView.isUserInteractionEnabled = false  // Don't intercept touches
    spacerView.widthAnchor.constraint(equalToConstant: heartSpacing - starSpacing).isActive = true
    stackView.addArrangedSubview(spacerView)
    
    // Add heart image view for favorite
    heartImageView = UIImageView()
    heartImageView.contentMode = .scaleAspectFit
    heartImageView.translatesAutoresizingMaskIntoConstraints = false
    heartImageView.isUserInteractionEnabled = true
    
    let heartConfig = UIImage.SymbolConfiguration(pointSize: starSize, weight: .regular)
    let heartImage = UIImage(systemName: "heart.fill")?.withConfiguration(heartConfig)
    heartImageView.image = heartImage?.withTintColor(Self.unselectedStarColor, renderingMode: .alwaysOriginal)
    
    NSLayoutConstraint.activate([
      heartImageView.widthAnchor.constraint(equalToConstant: starSize + 8),
      heartImageView.heightAnchor.constraint(equalToConstant: starSize + 8),
    ])
    
    // Add tap gesture for heart
    let heartTap = UITapGestureRecognizer(target: self, action: #selector(heartTapped(_:)))
    heartImageView.addGestureRecognizer(heartTap)
    
    stackView.addArrangedSubview(heartImageView)

    updateStarDisplay()
    updateHeartDisplay()
  }

  // MARK: - Actions

  @objc
  private func starTapped(_ sender: UITapGestureRecognizer) {
    guard isRatingEnabled, let starView = sender.view else { return }
    let newRating = starView.tag

    // If tapping the same star that represents current rating, clear it
    if newRating == rating {
      setRating(0, animated: true)
    } else {
      setRating(newRating, animated: true)
    }

    delegate?.ratingView(self, didChangeRating: rating)

    // Haptic feedback
    let generator = UIImpactFeedbackGenerator(style: .light)
    generator.impactOccurred()
  }

  @objc
  private func starLongPressed(_ sender: UILongPressGestureRecognizer) {
    guard isRatingEnabled, sender.state == .began else { return }

    setRating(0, animated: true)
    delegate?.ratingView(self, didChangeRating: rating)

    // Haptic feedback
    let generator = UIImpactFeedbackGenerator(style: .medium)
    generator.impactOccurred()
  }

  @objc
  private func heartTapped(_ sender: UITapGestureRecognizer) {
    guard isRatingEnabled else { return }

    setFavorite(!isFavorite, animated: true)
    delegate?.ratingView(self, didToggleFavorite: isFavorite)

    // Haptic feedback
    let generator = UIImpactFeedbackGenerator(style: .light)
    generator.impactOccurred()
  }

  // MARK: - Public Methods

  func setRating(_ newRating: Int, animated: Bool = false) {
    let clampedRating = max(0, min(starCount, newRating))

    if animated && clampedRating != rating {
      // Animate the change
      UIView.animate(withDuration: 0.15) {
        self.rating = clampedRating
      }
    } else {
      rating = clampedRating
    }
  }
  
  func setFavorite(_ newFavorite: Bool, animated: Bool = false) {
    if animated && newFavorite != isFavorite {
      UIView.animate(withDuration: 0.15) {
        self.isFavorite = newFavorite
      }
    } else {
      isFavorite = newFavorite
    }
  }
  
  /// Set whether the heart button is visible (hide when not a song)
  func setHeartVisible(_ visible: Bool) {
    heartImageView?.isHidden = !visible
  }

  // MARK: - Private Methods

  private func updateStarDisplay() {
    let config = UIImage.SymbolConfiguration(pointSize: starSize, weight: .regular)
    let baseImage = UIImage.starFill.withConfiguration(config)
    
    for (index, starView) in starImageViews.enumerated() {
      let starNumber = index + 1
      let isSelected = starNumber <= rating
      
      // Create pre-colored images to bypass tintColor override
      let color: UIColor
      if isRatingEnabled {
        color = isSelected ? Self.selectedStarColor : Self.unselectedStarColor
      } else {
        // Reduced opacity when disabled: 30% for selected, 5% for unselected
        color = isSelected
          ? Self.selectedStarColor.withAlphaComponent(0.3)
          : Self.unselectedStarColor.withAlphaComponent(0.05)
      }
      starView.image = baseImage.withTintColor(color, renderingMode: .alwaysOriginal)
    }
  }
  
  private func updateHeartDisplay() {
    guard let heartImageView = heartImageView else { return }
    
    let config = UIImage.SymbolConfiguration(pointSize: starSize, weight: .regular)
    let heartImage = UIImage(systemName: "heart.fill")?.withConfiguration(config)
    
    // Selected heart is red, unselected has same opacity as unselected stars
    let color: UIColor
    if isRatingEnabled {
      color = isFavorite ? .systemRed : Self.unselectedStarColor
    } else {
      // Reduced opacity when disabled: 30% for selected, 5% for unselected
      color = isFavorite
        ? UIColor.systemRed.withAlphaComponent(0.3)
        : Self.unselectedStarColor.withAlphaComponent(0.05)
    }
    heartImageView.image = heartImage?.withTintColor(color, renderingMode: .alwaysOriginal)
  }

  private func updateEnabledState() {
    // Update star and heart displays with appropriate opacity
    updateStarDisplay()
    updateHeartDisplay()
  }
}
