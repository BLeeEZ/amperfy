import Foundation

class ScrobbleEntry: NSObject {
    
    let managedObject: ScrobbleEntryMO

    init(managedObject: ScrobbleEntryMO) {
        self.managedObject = managedObject
    }
    
    var date: Date? {
        get { return managedObject.date }
        set { managedObject.date = newValue }
    }

    var isUploaded: Bool {
        get { return managedObject.isUploaded }
        set { managedObject.isUploaded = newValue }
    }

    var playable: AbstractPlayable? {
        get {
            guard let songMO = managedObject.playable else { return nil }
            return AbstractPlayable(managedObject: songMO)
        }
        set { managedObject.playable = newValue?.playableManagedObject }
    }
    
    override public func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? PlayableFile else { return false }
        return managedObject == object.managedObject
    }
    
}
