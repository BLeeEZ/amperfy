import Foundation
import CoreData
import UIKit

enum ImageStatus: Int16 {
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
    
    let managedObject: ArtworkMO
    
    init(managedObject: ArtworkMO) {
        self.managedObject = managedObject
    }

    static var defaultImage: UIImage = {
        return UIImage(named: "song") ?? UIImage()
    }()

    var id: String {
        get { return managedObject.id }
        set { if managedObject.id != newValue { managedObject.id = newValue } }
    }
    
    var type: String {
        get { return managedObject.type }
        set { if managedObject.type != newValue { managedObject.type = newValue } }
    }
    
    var status: ImageStatus {
        get { return ImageStatus(rawValue: managedObject.status) ?? .NotChecked }
        set { managedObject.status = newValue.rawValue }
    }
    
    var url: String {
        get { return managedObject.url ?? "" }
        set {
            if managedObject.url != newValue {
                status = .NotChecked
                managedObject.url = newValue
            }
        }
    }

    var image: UIImage? {
        var img: UIImage?
        switch status {
        case .CustomImage:
            if let data = managedObject.imageData {
                img = UIImage(data: data as Data)
            }
        default:
            img = Artwork.defaultImage
        }
        return img
    }
    
    func setImage(fromData: Data?) {
        managedObject.imageData = fromData
    }
    
    var owners: [AbstractLibraryEntity] {
        var returnOwners = [AbstractLibraryEntity]()
        guard let ownersSet = managedObject.owners, let ownersMO = ownersSet.allObjects as? [AbstractLibraryEntityMO] else { return returnOwners }
        
        for ownerMO in ownersMO {
            returnOwners.append(AbstractLibraryEntity(managedObject: ownerMO))
        }
        return returnOwners
    }
    
    var remoteInfo: ArtworkRemoteInfo {
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
    
    static func executeIf(entity: AbstractLibraryEntity, hasBeenUpdatedIn notification: Notification, completionHandler: ()->()) {
        let objKeys = [NSUpdatedObjectsKey, NSRefreshedObjectsKey]
        
        for objKey in objKeys {
            if let refreshedObjects = notification.userInfo?[objKey] as? Set<NSManagedObject>, !refreshedObjects.isEmpty {
                let foundReference = refreshedObjects.lazy.compactMap{ $0 as? ArtworkMO }.compactMap{ Artwork(managedObject: $0) }.filter{ $0.owners.contains(where: {$0.isEqual(entity)}) }.first
                if foundReference != nil { completionHandler(); return }
            }
        }
    }

}

extension Artwork: Downloadable {
    var objectID: NSManagedObjectID { return managedObject.objectID }
    var isCached: Bool { return false }
    var displayString: String { return "Artwork id: \(id), type: \(type)" }
}
