import Foundation

public class MusicFolder {
    
    static var typeName: String {
        return String(describing: Self.self)
    }
    
    let managedObject: MusicFolderMO
    
    init(managedObject: MusicFolderMO) {
        self.managedObject = managedObject
    }
    
    var id: String {
        get { return managedObject.id }
        set {
            if managedObject.id != newValue { managedObject.id = newValue }
        }
    }
    var name: String {
        get { return managedObject.name }
        set {
            if managedObject.name != newValue { managedObject.name = newValue }
        }
    }
    var directories: [Directory] {
        return managedObject.directories?.compactMap{ Directory(managedObject: $0 as! DirectoryMO) } ?? [Directory]()
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
