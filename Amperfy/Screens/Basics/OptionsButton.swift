//
//  OptionsButton.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 09.03.19.
//  Copyright (c) 2019 Maximilian Bauer. All rights reserved.
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

import UIKit
import AmperfyKit

class OptionsButton: UIButton {

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configureStyle()
    }
    
    func configureStyle() {
        layer.cornerRadius = 15
        self.backgroundColor = UIColor.defaultBlue
        self.tintColor = UIColor.white
        self.titleLabel?.font = UIFont.systemFont(ofSize: 26)
    }

}

class CloseBarButton: UIBarButtonItem {

    init(target: AnyObject, selector: Selector) {
        super.init()
        var config = UIButton.Configuration.gray()
        config.buttonSize = .small
        config.cornerStyle = .capsule
        let button = UIButton(configuration: config)
        button.addTarget(target, action: selector, for: .primaryActionTriggered)
        button.setImage(.xmark, for: .normal)
        button.showsMenuAsPrimaryAction = true
        self.customView = button
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

class OptionsBarButton: UIBarButtonItem {
    
    lazy var inUIButton = {
        var config = UIButton.Configuration.gray()
        #if !targetEnvironment(macCatalyst)
        config.buttonSize = .small
        config.cornerStyle = .capsule
        #endif
        
        let button = UIButton(configuration: config)
        #if targetEnvironment(macCatalyst)
        button.setTitle("\(CommonString.threeMiddleDots)  ", for: .normal)
        #else
        button.setImage(.ellipsis, for: .normal)
        #endif
        button.showsMenuAsPrimaryAction = true
        return button
    }()
    
    override init() {
        super.init()
        self.customView = inUIButton
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var menu: UIMenu? {
        set { inUIButton.menu = newValue }
        get { return inUIButton.menu }
    }
    
}

class SortBarButton: UIBarButtonItem {
    
    lazy var inUIButton = {
        var config = UIButton.Configuration.gray()
        #if !targetEnvironment(macCatalyst)
        config.buttonSize = .small
        config.cornerStyle = .capsule
        #endif

        let button = UIButton(configuration: config)
        #if targetEnvironment(macCatalyst)
        button.setTitle("\(CommonString.threeMiddleDots)  ", for: .normal)
        #else
        button.setImage(.filter, for: .normal)
        #endif
        button.showsMenuAsPrimaryAction = true
        return button
    }()
    
    override init() {
        super.init()
        self.customView = inUIButton
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var menu: UIMenu? {
        set { inUIButton.menu = newValue }
        get { return inUIButton.menu }
    }
    
}
