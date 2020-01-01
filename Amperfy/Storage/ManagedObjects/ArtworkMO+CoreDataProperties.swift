import Foundation
import CoreData


extension ArtworkMO {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ArtworkMO> {
        return NSFetchRequest<ArtworkMO>(entityName: "Artwork")
    }

    @NSManaged public var imageData: NSData?
    @NSManaged public var status: Int16
    @NSManaged public var url: String?
    @NSManaged public var owners: NSSet?

}

// MARK: Generated accessors for owners
extension ArtworkMO {

    @objc(addOwnersObject:)
    @NSManaged public func addToOwners(_ value: AbstractLibraryEntityMO)

    @objc(removeOwnersObject:)
    @NSManaged public func removeFromOwners(_ value: AbstractLibraryEntityMO)

    @objc(addOwners:)
    @NSManaged public func addToOwners(_ values: NSSet)

    @objc(removeOwners:)
    @NSManaged public func removeFromOwners(_ values: NSSet)

}
