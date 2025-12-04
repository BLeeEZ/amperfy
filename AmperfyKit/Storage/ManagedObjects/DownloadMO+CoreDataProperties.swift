//
//  DownloadMO+CoreDataProperties.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 21.07.21.
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

extension DownloadMO {
  @nonobjc
  public class func fetchRequest() -> NSFetchRequest<DownloadMO> {
    NSFetchRequest<DownloadMO>(entityName: "Download")
  }

  @NSManaged
  public var account: AccountMO?
  @NSManaged
  public var creationDate: Date?
  @NSManaged
  public var errorDate: Date?
  @NSManaged
  public var errorType: Int16
  @NSManaged
  public var finishDate: Date?
  @NSManaged
  public var id: String
  @NSManaged
  public var progressPercent: Float
  @NSManaged
  public var startDate: Date?
  @NSManaged
  public var totalSize: String?
  @NSManaged
  public var resumeData: Data?
  @available(*, deprecated, message: "Download URL will not be saved in Core Data anymore.")
  @NSManaged
  public var urlString: String
  @NSManaged
  public var artwork: ArtworkMO?
  @NSManaged
  public var playable: AbstractPlayableMO?

  static let relationshipKeyPathsForPrefetching = [
    #keyPath(DownloadMO.artwork),
    #keyPath(DownloadMO.playable),
  ]
}
