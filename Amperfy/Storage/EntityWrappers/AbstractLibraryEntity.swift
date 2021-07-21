import Foundation
import UIKit

public class AbstractLibraryEntity {

    private let managedObject: AbstractLibraryEntityMO
    
    static var typeName: String {
        return String(describing: Self.self)
    }
    
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
    func isEqual(_ other: AbstractLibraryEntity) -> Bool {
        return managedObject == other.managedObject
    }

}
