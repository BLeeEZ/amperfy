import Foundation
import UIKit

public class EmbeddedArtwork: NSObject {
    
    public let managedObject: EmbeddedArtworkMO
    
    public init(managedObject: EmbeddedArtworkMO) {
        self.managedObject = managedObject
    }

    public var image: UIImage? {
        guard let imageData = managedObject.imageData else { return nil }
        return UIImage(data: imageData)
    }
    
    public func setImage(fromData: Data?) {
        managedObject.imageData = fromData
    }
    
    public var owner: AbstractPlayable? {
        get {
            guard let ownerMO = managedObject.owner else { return nil }
            return AbstractPlayable(managedObject: ownerMO)
        }
        set { if managedObject.owner != newValue?.playableManagedObject { managedObject.owner = newValue?.playableManagedObject } }
    }
    
}
