//
//  FlexibleSpaceBarItem.swift
//  Amperfy
//
//  Created by David Klopp on 22.08.24.
//  Copyright © 2024 Maximilian Bauer. All rights reserved.
//

import Foundation
import UIKit

#if targetEnvironment(macCatalyst)

// Hack: built-in flexible space navigation bar item is not working, so we use this workaround
class SpaceBarItem: UIBarButtonItem {
    convenience init(fixedSpace: CGFloat, priority: UILayoutPriority = .defaultHigh) {
        self.init(minSpace: fixedSpace, maxSpace: fixedSpace, priority: priority)
    }

    init(minSpace: CGFloat = 0, maxSpace: CGFloat = 10000, priority: UILayoutPriority = .defaultHigh) {
        super.init()

        let clearView = UIView(frame: .zero)
        clearView.backgroundColor = .clear

        clearView.translatesAutoresizingMaskIntoConstraints = false

        let maxWidthConstraint = clearView.widthAnchor.constraint(lessThanOrEqualToConstant: maxSpace)
        maxWidthConstraint.priority = priority

        NSLayoutConstraint.activate([
            maxWidthConstraint,
            clearView.widthAnchor.constraint(greaterThanOrEqualToConstant: minSpace),
            // This allows us to still grab and move the window when clicking the empty space
            clearView.heightAnchor.constraint(equalToConstant: 0)
        ])

        self.customView = clearView
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

#endif
