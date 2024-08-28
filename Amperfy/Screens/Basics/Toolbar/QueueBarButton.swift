//
//  QueueButtonBarButton.swift
//  Amperfy
//
//  Created by David Klopp on 28.08.24.
//  Copyright © 2024 Maximilian Bauer. All rights reserved.
//

import Foundation
import UIKit
import MediaPlayer

#if targetEnvironment(macCatalyst)

class QueueBarButton: CustomBarButton {
    let splitViewController: SplitVC

    init(splitViewController: SplitVC) {
        self.splitViewController = splitViewController
        super.init(image: .listBullet)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func clicked(_ sender: UIButton) {
        self.splitViewController.macToolbarHostingViewController?.toggleSlideOverView()
    }
}

#endif

