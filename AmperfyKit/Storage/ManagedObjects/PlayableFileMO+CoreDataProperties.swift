//
//  PlayableFileMO+CoreDataProperties.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 29.06.21.
//  Copyright (c) 2021 Maximilian Bauer. All rights reserved.
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

import CoreData
import Foundation

extension PlayableFileMO {
  @nonobjc
  public class func fetchRequest() -> NSFetchRequest<PlayableFileMO> {
    NSFetchRequest<PlayableFileMO>(entityName: "PlayableFile")
  }

  @NSManaged
  public var data: Data?
  @NSManaged
  public var info: AbstractPlayableMO?
}
