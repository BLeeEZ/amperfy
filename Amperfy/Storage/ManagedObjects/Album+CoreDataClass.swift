import Foundation
import CoreData
import UIKit

@objc(Album)
public class Album: AbstractLibraryElementMO {

    override var identifier: String {
        return name ?? ""
    }
    
    override var image: UIImage {
        if super.image != Artwork.defaultImage {
            return super.image
        }
        if let artistArt = artist?.artwork?.image {
            return artistArt
        }
        return Artwork.defaultImage
    }

}
