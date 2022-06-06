import Foundation

public class MusicFolder {
    
    public static var typeName: String {
        return String(describing: Self.self)
    }
    
    public let managedObject: MusicFolderMO
    
    public init(managedObject: MusicFolderMO) {
        self.managedObject = managedObject
    }
    
    public var id: String {
        get { return managedObject.id }
        set {
            if managedObject.id != newValue { managedObject.id = newValue }
        }
    }
    public var name: String {
        get { return managedObject.name }
        set {
            if managedObject.name != newValue { managedObject.name = newValue }
        }
    }
    public var directories: [Directory] {
        return managedObject.directories?.compactMap{ Directory(managedObject: $0 as! DirectoryMO) } ?? [Directory]()
    }
    public var songs: [Song] {
        return managedObject.songs?.compactMap{ Song(managedObject: $0 as! SongMO) } ?? [Song]()
    }

}

extension MusicFolder: Hashable, Equatable {
    public static func == (lhs: MusicFolder, rhs: MusicFolder) -> Bool {
        return lhs.managedObject == rhs.managedObject && lhs.managedObject == rhs.managedObject
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(managedObject)
    }
}
