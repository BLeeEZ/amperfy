//
//  FontAwesomeIcon.swift
//  AmperfyKit
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

import Foundation

public enum FontAwesomeIcon: Int {
    
    case Play = 0xf04b
    case Pause = 0xf04c
    case VolumeUp = 0xf028
    case Cloud = 0xf0c2
    case Redo = 0xf01e
    case Check = 0xf00c
    case Bars = 0xf0c9
    case SortDown = 0xf0dd
    case Exclamation = 0xf12a
    case Sync = 0xf021
    case Info = 0xf129
    case Podcast = 0xf2ce
    case Ban = 0xf05e
    case Bell = 0xf0f3
    case Star = 0xf005
    case Heart = 0xf004
    case Sort = 0xf160
    case Filter = 0xf0b0
    
    public var asString: String {
        return String(format: "%C", self.rawValue)
    }
    
    public static var fontNameRegular: String {
        return "FontAwesome5Free-Regular"
    }
    public static var fontNameSolid: String {
        return "FontAwesome5FreeSolid"
    }
    public static var fontName: String {
        return "FontAwesome5FreeSolid"
    }
}
