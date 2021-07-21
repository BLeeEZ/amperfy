import Foundation
import CoreData

class Download: NSObject {
    
    let managedObject: DownloadMO
    
    init(managedObject: DownloadMO) {
        self.managedObject = managedObject
        super.init()
        if creationDate == nil {
            creationDate = Date()
        }
    }
    
    var resumeData: Data? // Will not be saved in CoreData
    
    var title: String {
        return element.displayString
    }
    
    var isFinishedSuccessfully: Bool {
        return finishDate != nil && errorDate == nil
    }
    
    var isCanceled: Bool {
        get {
            guard let error = error else { return false }
            return error == .canceled
        }
        set { if newValue { error = .canceled } }
    }

    var id: String {
        get { return managedObject.id }
        set { if managedObject.id != newValue { managedObject.id = newValue } }
    }
    var isDownloading: Bool {
        get { return startDate != nil && finishDate == nil && errorDate == nil}
        set { newValue ? (startDate = Date()) : (finishDate = Date()) }
    }
    var url: URL {
        get { return URL(string: urlString)! }
        set { if managedObject.urlString != newValue.absoluteString { managedObject.urlString = newValue.absoluteString } }
    }
    var urlString: String {
        get { return managedObject.urlString }
        set { if managedObject.urlString != newValue { managedObject.urlString = newValue } }
    }
    var creationDate: Date? {
        get { return managedObject.creationDate }
        set { if managedObject.creationDate != newValue { managedObject.creationDate = newValue } }
    }
    var errorDate: Date? {
        get { return managedObject.errorDate }
        set { if managedObject.errorDate != newValue { managedObject.errorDate = newValue } }
    }
    private var errorType: Int? {
        get {
            guard errorDate != nil else { return nil }
            return Int(managedObject.errorType)
        }
        set {
            guard let newValue = newValue, Int16.isValid(value: newValue), managedObject.errorType != Int16(newValue) else { return }
            managedObject.errorType = Int16(newValue)
        }
    }
    var error: DownloadError? {
        get {
            guard let errorType = errorType else { return nil }
            return DownloadError.create(rawValue: errorType)
        }
        set {
            if newValue != nil {
                errorDate = Date()
                errorType = newValue?.rawValue
            }
        }
    }
    var finishDate: Date? {
        get { return managedObject.finishDate }
        set { if managedObject.finishDate != newValue { managedObject.finishDate = newValue } }
    }
    var progress: Float {
        get { return managedObject.progressPercent }
        set { if managedObject.progressPercent != newValue { managedObject.progressPercent = newValue } }
    }
    var startDate: Date? {
        get { return managedObject.startDate }
        set { if managedObject.startDate != newValue { managedObject.startDate = newValue } }
    }
    var totalSize: String {
        get { return managedObject.totalSize ?? "" }
        set { if managedObject.totalSize != newValue { managedObject.totalSize = totalSize } }
    }
    var element: Downloadable {
        get {
            if let artwork = artwork {
                return artwork
            } else if let playable = playable {
                return playable
            } else {
                fatalError("Download does not contain a valid target element!")
            }
        }
        set {
            if let context = managedObject.managedObjectContext {
                if let downloadable = newValue as? AbstractPlayable {
                    playable = AbstractPlayable(managedObject: context.object(with: downloadable.objectID) as! AbstractPlayableMO)
                } else if let downloadable = newValue as? Artwork {
                    artwork = Artwork(managedObject: context.object(with: downloadable.objectID) as! ArtworkMO)
                }
            }
        }
    }
    private var artwork: Artwork? {
        get {
            guard let artworkMO = managedObject.artwork else { return nil }
            return Artwork(managedObject: artworkMO) }
        set {
            if managedObject.artwork != newValue?.managedObject { managedObject.artwork = newValue?.managedObject }
        }
    }
    private var playable: AbstractPlayable? {
        get {
            guard let playableMO = managedObject.playable else { return nil }
            return AbstractPlayable(managedObject: playableMO) }
        set {
            if managedObject.playable != newValue?.playableManagedObject { managedObject.playable = newValue?.playableManagedObject }
        }
    }
    
}
