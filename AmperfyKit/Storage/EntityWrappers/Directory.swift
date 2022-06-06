import Foundation

public class Directory: AbstractLibraryEntity {
    
    public let managedObject: DirectoryMO
    
    public init(managedObject: DirectoryMO) {
        self.managedObject = managedObject
        super.init(managedObject: managedObject)
    }
    
    public var name: String {
        get { return managedObject.name ?? "" }
        set {
            if managedObject.name != newValue { managedObject.name = newValue }
        }
    }
    public var songs: [Song] {
        return managedObject.songs?.compactMap{ Song(managedObject: $0 as! SongMO) } ?? [Song]()
    }
    public var subdirectories: [Directory] {
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
