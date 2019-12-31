import Foundation
import CoreData
import UIKit

@objc(AbstractLibraryEntityMO)
public class AbstractLibraryEntityMO: NSManagedObject, Identifyable {

    var image: UIImage {
        guard let art = artwork?.image else {
            return Artwork.defaultImage
        }
        return art
    }
    
    // Identifyable
    var identifier: String {
        return ""
    }
}
