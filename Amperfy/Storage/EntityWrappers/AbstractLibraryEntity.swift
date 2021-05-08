import Foundation
import UIKit

public class AbstractLibraryEntity: NSObject {

    private let managedObject: AbstractLibraryEntityMO
    
    init(managedObject: AbstractLibraryEntityMO) {
        self.managedObject = managedObject
    }
    
    var id: String {
        get { return managedObject.id }
        set {
            if managedObject.id != newValue { managedObject.id = newValue }
        }
    }
    var artwork: Artwork? {
        get {
            guard let artworkMO = managedObject.artwork else { return nil }
            return Artwork(managedObject: artworkMO)
        }
        set {
            if managedObject.artwork != newValue?.managedObject { managedObject.artwork = newValue?.managedObject }
        }
    }
    var image: UIImage {
        guard let img = artwork?.image else {
            return Artwork.defaultImage
        }
        return img
    }
    
    override public func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? AbstractLibraryEntity else { return false }
        return managedObject == object.managedObject
    }

}
