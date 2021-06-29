import Foundation
import CoreData

public class PlayableFile: NSObject {
    
    let managedObject: PlayableFileMO

    init(managedObject: PlayableFileMO) {
        self.managedObject = managedObject
    }

    var info: AbstractPlayable? {
        get {
            guard let songMO = managedObject.info else { return nil }
            return AbstractPlayable(managedObject: songMO)
        }
        set {
            guard let playable = newValue else {
                managedObject.info = nil
                return
            }
            managedObject.info = playable.playableManagedObject
        }
    }
    
    var data: Data? {
        get {
            return managedObject.data
        }
        set {
            managedObject.data = newValue
        }
    }
    
    override public func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? PlayableFile else { return false }
        return managedObject == object.managedObject
    }

}
