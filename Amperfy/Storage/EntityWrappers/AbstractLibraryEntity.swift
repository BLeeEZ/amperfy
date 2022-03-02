import Foundation
import UIKit

enum RemoteStatus: Int {
    case available = 0
    case deleted = 1
}

public class AbstractLibraryEntity {

    private let managedObject: AbstractLibraryEntityMO
    
    static var typeName: String {
        return String(describing: Self.self)
    }
    
    init(managedObject: AbstractLibraryEntityMO) {
        self.managedObject = managedObject
    }
    
    var id: String {
        get { return managedObject.id }
        set {
            if managedObject.id != newValue { managedObject.id = newValue }
        }
    }
    var rating: Int {
        get { return Int(managedObject.rating) }
        set {
            guard Int16.isValid(value: newValue), managedObject.rating != Int16(newValue), newValue >= 0, newValue <= 5 else { return }
            managedObject.rating = Int16(newValue)
        }
    }
    var remoteStatus: RemoteStatus {
        get { return RemoteStatus(rawValue: Int(managedObject.remoteStatus)) ?? .available }
        set {
            guard Int16.isValid(value: newValue.rawValue), managedObject.remoteStatus != Int16(newValue.rawValue) else { return }
            managedObject.remoteStatus = Int16(newValue.rawValue)
        }
    }
    var playCount: Int {
        get { return Int(managedObject.playCount) }
        set {
            guard Int32.isValid(value: newValue), managedObject.playCount != Int32(newValue) else { return }
            managedObject.playCount = Int32(newValue)
        }
    }
    var lastTimePlayed: Date? {
        get { return managedObject.lastPlayedDate }
        set { if managedObject.lastPlayedDate != newValue { managedObject.lastPlayedDate = newValue } }
    }
    var artwork: Artwork? {
        get {
            guard let artworkMO = managedObject.artwork else { return nil }
            return Artwork(managedObject: artworkMO)
        }
        set {
            if managedObject.artwork != newValue?.managedObject { managedObject.artwork = newValue?.managedObject }
        }
    }
    var image: UIImage {
        guard let img = artwork?.image else {
            return defaultImage
        }
        return img
    }
    var defaultImage: UIImage {
        return UIImage.songArtwork
    }
    func isEqual(_ other: AbstractLibraryEntity) -> Bool {
        return managedObject == other.managedObject
    }
    
    func playedViaContext() {
        lastTimePlayed = Date()
        playCount += 1
    }

}
