import Foundation
import CoreData


extension Artwork {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Artwork> {
        return NSFetchRequest<Artwork>(entityName: "Artwork")
    }

    @NSManaged public var imageData: NSData?
    @NSManaged public var statusMO: Int16
    @NSManaged public var urlMO: String?
    @NSManaged public var owners: NSSet?

}

// MARK: Generated accessors for owners
extension Artwork {

    @objc(addOwnersObject:)
    @NSManaged public func addToOwners(_ value: AbstractLibraryElementMO)

    @objc(removeOwnersObject:)
    @NSManaged public func removeFromOwners(_ value: AbstractLibraryElementMO)

    @objc(addOwners:)
    @NSManaged public func addToOwners(_ values: NSSet)

    @objc(removeOwners:)
    @NSManaged public func removeFromOwners(_ values: NSSet)

}
