import Foundation
import UIKit

public class AbstractLibraryElement: NSObject, Identifyable {

    private let managedObject: AbstractLibraryElementMO
    
    init(managedObject: AbstractLibraryElementMO) {
        self.managedObject = managedObject
    }
    
    var id: Int {
        get { return Int(managedObject.id) }
        set { managedObject.id = Int32(newValue) }
    }
    var artwork: Artwork? {
        get { return managedObject.artwork }
        set { managedObject.artwork = newValue }
    }
    var image: UIImage {
        guard let art = managedObject.artwork?.image else {
            return Artwork.defaultImage
        }
        return art
    }
    var identifier: String {
        return ""
    }
}
