import Foundation
import UIKit

public class EmbeddedArtwork: NSObject {
    
    let managedObject: EmbeddedArtworkMO
    
    init(managedObject: EmbeddedArtworkMO) {
        self.managedObject = managedObject
    }

    var image: UIImage? {
        guard let imageData = managedObject.imageData else { return nil }
        return UIImage(data: imageData)
    }
    
    func setImage(fromData: Data?) {
        managedObject.imageData = fromData
    }
    
    var owner: AbstractPlayable? {
        get {
            guard let ownerMO = managedObject.owner else { return nil }
            return AbstractPlayable(managedObject: ownerMO)
        }
        set { if managedObject.owner != newValue?.playableManagedObject { managedObject.owner = newValue?.playableManagedObject } }
    }
    
}
