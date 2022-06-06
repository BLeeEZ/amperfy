import Foundation

public class ScrobbleEntry: NSObject {
    
    public let managedObject: ScrobbleEntryMO

    public init(managedObject: ScrobbleEntryMO) {
        self.managedObject = managedObject
    }
    
    public var date: Date? {
        get { return managedObject.date }
        set { managedObject.date = newValue }
    }

    public var isUploaded: Bool {
        get { return managedObject.isUploaded }
        set { managedObject.isUploaded = newValue }
    }

    public var playable: AbstractPlayable? {
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
