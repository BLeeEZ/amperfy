//
//  Artwork.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 01.01.20.
//  Copyright (c) 2020 Maximilian Bauer. All rights reserved.
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
import CoreData
import UIKit

public enum ImageStatus: Int16 {
    case IsDefaultImage = 0
    case NotChecked = 1
    case CustomImage = 2
    case FetchError = 3
}

public struct ArtworkRemoteInfo {
    public var id: String
    public var type: String
}

public class Artwork: NSObject {
    
    public let managedObject: ArtworkMO
    
    public init(managedObject: ArtworkMO) {
        self.managedObject = managedObject
    }

    public var id: String {
        get { return managedObject.id }
        set { if managedObject.id != newValue { managedObject.id = newValue } }
    }
    
    public var type: String {
        get { return managedObject.type }
        set { if managedObject.type != newValue { managedObject.type = newValue } }
    }
    
    public var status: ImageStatus {
        get { return ImageStatus(rawValue: managedObject.status) ?? .NotChecked }
        set { managedObject.status = newValue.rawValue }
    }
    
    public var url: String {
        get { return managedObject.url ?? "" }
        set {
            if managedObject.url != newValue {
                status = .NotChecked
                managedObject.url = newValue
            }
        }
    }

    public var image: UIImage? {
        var img: UIImage?
        switch status {
        case .CustomImage:
            if let data = managedObject.imageData {
                img = UIImage(data: data as Data)
            }
        default:
            break
        }
        return img
    }
    
    public func setImage(fromData: Data?) {
        managedObject.imageData = fromData
    }
    
    public var owners: [AbstractLibraryEntity] {
        var returnOwners = [AbstractLibraryEntity]()
        guard let ownersSet = managedObject.owners, let ownersMO = ownersSet.allObjects as? [AbstractLibraryEntityMO] else { return returnOwners }
        
        for ownerMO in ownersMO {
            returnOwners.append(AbstractLibraryEntity(managedObject: ownerMO))
        }
        return returnOwners
    }
    
    public var remoteInfo: ArtworkRemoteInfo {
        get { return ArtworkRemoteInfo(id: managedObject.id, type: managedObject.type) }
        set {
            self.id = newValue.id
            self.type = newValue.type
        }
    }
    
    override public func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? Artwork else { return false }
        return managedObject == object.managedObject
    }
    
}

extension Artwork: Downloadable {
    public var objectID: NSManagedObjectID { return managedObject.objectID }
    public var isCached: Bool { return false }
    public var displayString: String { return "Artwork id: \(id), type: \(type)" }
}
