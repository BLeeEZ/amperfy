import Foundation
import CoreData

public class SongFile: NSObject {
    
    let managedObject: SongFileMO

    init(managedObject: SongFileMO) {
        self.managedObject = managedObject
    }

    var info: Song? {
        get {
            guard let songMO = managedObject.info else { return nil }
            return Song(managedObject: songMO)
        }
        set {
            guard let song = newValue else {
                managedObject.info = nil
                return
            }
            managedObject.info = song.managedObject
        }
    }
    
    var data: NSData? {
        get {
            return managedObject.data
        }
        set {
            managedObject.data = newValue
        }
    }
    
}
