//
//  AirplayBarButton.swift
//  Amperfy
//
//  Created by David Klopp on 22.08.24.
//  Copyright (c) 2024 Maximilian Bauer. All rights reserved.
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
import MediaPlayer
import UIKit

#if targetEnvironment(macCatalyst)

  class AirplayBarButton: CustomBarButton {
    override var title: String? {
      get { "Airplay" }
      set {}
    }

    private lazy var airplayVolume: MPVolumeView = {
      let volumeView = MPVolumeView(frame: .zero)
      volumeView.showsVolumeSlider = false
      volumeView.isHidden = true
      return volumeView
    }()

    init() {
      super.init(image: .airplayaudio)

      guard let customView = customView else { return }
      customView.addSubview(airplayVolume)

      airplayVolume.translatesAutoresizingMaskIntoConstraints = false
      NSLayoutConstraint.activate([
        airplayVolume.topAnchor.constraint(equalTo: customView.topAnchor),
        airplayVolume.bottomAnchor.constraint(equalTo: customView.bottomAnchor),
        airplayVolume.leadingAnchor.constraint(equalTo: customView.leadingAnchor),
        airplayVolume.trailingAnchor.constraint(equalTo: customView.trailingAnchor),
      ])

      // Force a layout since the view is hidden
      airplayVolume.layoutIfNeeded()
    }

    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    override func clicked(_ sender: UIButton) {
      for view: UIView in airplayVolume.subviews {
        if let button = view as? UIButton {
          button.sendActions(for: .touchUpInside)
          break
        }
      }
    }
  }

#endif
