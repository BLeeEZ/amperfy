//
//  BackButtonBarItem.swift
//  Amperfy
//
//  Created by David Klopp on 22.08.24.
//  Copyright © 2024 Maximilian Bauer. All rights reserved.
//

import Foundation
import UIKit
import MediaPlayer

#if targetEnvironment(macCatalyst)

class AirplayButtonBarItem: CustomBarButton {
    private lazy var airplayVolume: MPVolumeView = {
        let volumeView = MPVolumeView(frame: .zero)
        volumeView.showsVolumeSlider = false
        volumeView.isHidden = true
        return volumeView
    }()

    init() {
        super.init(image: .airplayaudio)

        guard let customView = self.customView else { return }
        customView.addSubview(self.airplayVolume)

        self.airplayVolume.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            self.airplayVolume.topAnchor.constraint(equalTo: customView.topAnchor),
            self.airplayVolume.bottomAnchor.constraint(equalTo: customView.bottomAnchor),
            self.airplayVolume.leadingAnchor.constraint(equalTo: customView.leadingAnchor),
            self.airplayVolume.trailingAnchor.constraint(equalTo: customView.trailingAnchor)
        ])

        // Force a layout since the view is hidden
        self.airplayVolume.layoutIfNeeded()
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
