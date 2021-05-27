import Foundation

public class Directory: AbstractLibraryEntity {
    
    let managedObject: DirectoryMO
    
    init(managedObject: DirectoryMO) {
        self.managedObject = managedObject
        super.init(managedObject: managedObject)
    }
    
    var name: String {
        get { return managedObject.name ?? "" }
        set {
            if managedObject.name != newValue { managedObject.name = newValue }
        }
    }
    var songs: [Song] {
        return managedObject.songs?.compactMap{ Song(managedObject: $0 as! SongMO) } ?? [Song]()
    }
    var subdirectories: [Directory] {
        return managedObject.subdirectories?.compactMap{ Directory(managedObject: $0 as! DirectoryMO) } ?? [Directory]()
    }

}

extension Directory: Hashable, Equatable {
    public static func == (lhs: Directory, rhs: Directory) -> Bool {
        return lhs.managedObject == rhs.managedObject && lhs.managedObject == rhs.managedObject
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(managedObject)
    }
}
