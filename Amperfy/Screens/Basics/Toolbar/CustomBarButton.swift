//
//  CustomBarButton.swift
//  Amperfy
//
//  Created by David Klopp on 22.08.24.
//  Copyright © 2024 Maximilian Bauer. All rights reserved.
//

import Foundation
import UIKit

#if targetEnvironment(macCatalyst)

// MacOS BarButtonItems can not be disabled. Thats, why we create a custom BarButtonItem.
class CustomBarButton: UIBarButtonItem, Refreshable {
    let pointSize: CGFloat

    var inUIButton: UIButton? {
        self.customView as? UIButton
    }

    var hovered: Bool = false {
        didSet {
            if (self.hovered) {
                self.inUIButton?.backgroundColor = .systemGray2.withAlphaComponent(0.2)
            } else {
                self.inUIButton?.backgroundColor = .clear
            }
        }
    }

    var active: Bool = false {
        didSet{
            guard let image = self.inUIButton?.configuration?.image else { return }
            self.updateImage(image: image)
        }
    }

    private var currentTint: UIColor {
        if (self.active) {
            .label
        } else {
            .secondaryLabel
        }
    }

    func updateImage(image: UIImage) {
        self.inUIButton?.configuration?.image = image.styleForNavigationBar(pointSize: self.pointSize, tintColor: self.currentTint)
    }

    func createInUIButton(config: UIButton.Configuration, size: CGSize) -> UIButton? {
        let button = UIButton(configuration: config)
        button.imageView?.contentMode = .scaleAspectFit

        // influence the highlighted area
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: size.width).isActive = true
        button.heightAnchor.constraint(equalToConstant: size.height).isActive = true

        return button
    }

    override var isEnabled: Bool {
        get { super.isEnabled }
        set(newValue) {
            super.isEnabled = newValue
            self.customView?.isUserInteractionEnabled = newValue
        }
    }

    init(image: UIImage?, pointSize: CGFloat = 18) {
        self.pointSize = pointSize
        super.init()

        var config = UIButton.Configuration.gray()
        config.macIdiomStyle = .borderless
        config.image = image?.styleForNavigationBar(pointSize: self.pointSize, tintColor: self.currentTint)
        let button = createInUIButton(config: config, size: CGSize(width: 32, height: 22))
        button?.addTarget(self, action: #selector(self.clicked(_:)), for: .touchUpInside)
        button?.layer.cornerRadius = 5
        self.customView = button

        // Recreate the system button background highlight
        self.installHoverGestureRecognizer()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func installHoverGestureRecognizer() {
        let recognizer = UIHoverGestureRecognizer(target: self, action: #selector(self.hoverButton(_:)))
        self.inUIButton?.addGestureRecognizer(recognizer)
    }

    @objc private func hoverButton(_ recognizer: UIHoverGestureRecognizer) {
        switch recognizer.state {
        case .began:
            self.hovered = true
        case .ended, .cancelled, .failed:
            self.hovered = self.active
        default:
            break
        }
    }

    @objc func clicked(_ sender: UIButton) {

    }

    func reload() {}
}

#endif
