//
//  BackButtonBarItem.swift
//  Amperfy
//
//  Created by David Klopp on 22.08.24.
//  Copyright © 2024 Maximilian Bauer. All rights reserved.
//

import Foundation
import UIKit

#if targetEnvironment(macCatalyst)

class BackButtonBarItem: CustomBarButton {
    var navigationController: UINavigationController?

    init() {
        super.init(image: .chevronLeft, pointSize: 16)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func clicked(_ sender: UIButton) {
        self.navigationController?.popViewController(animated: true)
        self.reload()
    }

    override func reload() {
        let vcs = self.navigationController?.viewControllers.count ?? 0
        // Let the hover gesture fail
        self.customView?.gestureRecognizers?.forEach { $0.isEnabled = false }
        self.customView?.gestureRecognizers?.forEach { $0.isEnabled = (vcs > 1) }
        self.isEnabled = (vcs > 1)
    }
}

#endif
