import Foundation
import UIKit

public class AbstractLibraryEntity: NSObject, Identifyable {

    private let managedObject: AbstractLibraryEntityMO
    
    init(managedObject: AbstractLibraryEntityMO) {
        self.managedObject = managedObject
    }
    
    var id: Int {
        get { return Int(managedObject.id) }
        set { managedObject.id = Int32(newValue) }
    }
    var artwork: Artwork? {
        get {
            guard let artworkMO = managedObject.artwork else { return nil }
            return Artwork(managedObject: artworkMO)
        }
        set { managedObject.artwork = newValue?.managedObject }
    }
    var image: UIImage {
        guard let img = artwork?.image else {
            return Artwork.defaultImage
        }
        return img
    }
    var identifier: String {
        return ""
    }
    
    override public func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? AbstractLibraryEntity else { return false }
        return managedObject == object.managedObject
    }

}
