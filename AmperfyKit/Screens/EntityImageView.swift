//
//  EntityImageView.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 20.02.22.
//  Copyright (c) 2022 Maximilian Bauer. All rights reserved.
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

import Foundation
import UIKit

open class EntityImageView: UIView {
  @IBOutlet
  weak var singleImage: LibraryEntityImage!
  @IBOutlet
  weak var quadImage1: LibraryEntityImage!
  @IBOutlet
  weak var quadImage2: LibraryEntityImage!
  @IBOutlet
  weak var quadImage3: LibraryEntityImage!
  @IBOutlet
  weak var quadImage4: LibraryEntityImage!

  private var view: UIView!

  private var quadImages: [LibraryEntityImage] {
    [
      quadImage1,
      quadImage2,
      quadImage3,
      quadImage4,
    ]
  }

  required public init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    loadViewFromNib()
  }

  override public init(frame: CGRect) {
    super.init(frame: frame)
    loadViewFromNib()
  }

  public func loadViewFromNib() {
    let bundle = Bundle(for: type(of: self))
    let nib = UINib(nibName: String(describing: type(of: self)), bundle: bundle)
    let view = nib.instantiate(withOwner: self, options: nil).first as! UIView
    view.frame = bounds
    view.autoresizingMask = [
      UIView.AutoresizingMask.flexibleWidth,
      UIView.AutoresizingMask.flexibleHeight,
    ]
    addSubview(view)
    self.view = view

    backgroundColor = .clear

    layer.masksToBounds = true
    self.view.backgroundColor = .clear
    self.view.layoutMargins = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    quadImages[0].layer.maskedCorners = [
      .layerMinXMinYCorner,
      .layerMaxXMinYCorner,
      .layerMinXMaxYCorner,
      .layerMaxXMaxYCorner,
    ]
    quadImages[0].layer.maskedCorners = [.layerMinXMinYCorner]
    quadImages[1].layer.maskedCorners = [.layerMaxXMinYCorner]
    quadImages[2].layer.maskedCorners = [.layerMinXMaxYCorner]
    quadImages[3].layer.maskedCorners = [.layerMaxXMaxYCorner]
  }

  public func display(
    theme: ThemePreference,
    container: PlayableContainable,
    cornerRadius: CornerRadius = .small
  ) {
    display(
      theme: theme,
      collection: container.getArtworkCollection(theme: theme),
      cornerRadius: cornerRadius
    )
  }

  public func configureStyling(
    image: UIImage,
    imageSizeType: ArtworkIconSizeType,
    imageTintColor: UIColor,
    backgroundColor: UIColor
  ) {
    singleImage.tintColor = imageTintColor
    view.backgroundColor = backgroundColor
    view.layoutMargins = UIEdgeInsets(
      top: imageSizeType.rawValue,
      left: imageSizeType.rawValue,
      bottom: imageSizeType.rawValue,
      right: imageSizeType.rawValue
    )
    let modImage = image.withRenderingMode(.alwaysTemplate)
    singleImage.display(image: modImage)
  }

  private func display(
    theme: ThemePreference,
    collection: ArtworkCollection,
    cornerRadius: CornerRadius = .small
  ) {
    layer.cornerRadius = cornerRadius.asCGFloat
    quadImages.forEach { $0.isHidden = true }
    singleImage.isHidden = false

    if let quadEntities = collection.quadImageEntity {
      if quadEntities.count > 1 {
        // check if all images are the same
        if Set(quadEntities.compactMap { $0.artwork?.id }).count == 1 {
          singleImage.displayAndUpdate(entity: quadEntities.first!)
        } else {
          singleImage.isHidden = true
          quadImages.forEach {
            $0.display(image: UIImage.getGeneratedArtwork(theme: theme, artworkType: .song))
            $0.isHidden = false
          }
          for (index, entity) in quadEntities.enumerated() {
            guard index < quadImages.count else { break }
            quadImages[index].display(entity: entity)
          }
        }
      } else if let firstEntity = quadEntities.first {
        singleImage.displayAndUpdate(entity: firstEntity)
      } else {
        singleImage.display(artworkType: collection.defaultArtworkType)
      }
    } else if let singleEntity = collection.singleImageEntity {
      singleImage.displayAndUpdate(entity: singleEntity)
    } else {
      singleImage.display(artworkType: collection.defaultArtworkType)
    }
  }
}
