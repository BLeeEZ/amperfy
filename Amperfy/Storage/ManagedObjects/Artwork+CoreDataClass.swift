import Foundation
import CoreData
import UIKit

enum ImageStatus: Int16 {
    case IsDefaultImage = 0
    case NotChecked = 1
    case CustomImage = 2
    case FetchError = 3
}

@objc(Artwork)
public class Artwork: NSManagedObject {
    
    static var defaultImage: UIImage = {
        return UIImage(named: "song")!
    }()

    var status: ImageStatus {
        get {
            return ImageStatus(rawValue: statusMO) ?? .NotChecked
        }
        set {
            statusMO = newValue.rawValue
        }
    }
    
    var url: String {
        get {
            return urlMO ?? ""
        }
        set {
            status = .NotChecked
            urlMO = newValue
        }
    }

    var image: UIImage? {
        var img: UIImage?
        switch status {
        case .CustomImage:
            if let data = imageData {
                img = UIImage(data: data as Data)
            }
        default:
            img = Artwork.defaultImage
        }
        return img
    }
    
}
