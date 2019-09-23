import Foundation
import CoreData
import UIKit

@objc(Song)
public class Song: AbstractLibraryElementMO {

    override var identifier: String {
        return title ?? ""
    }

    override var image: UIImage {
        if let curAlbum = album, !curAlbum.isOrphaned {
            if super.image != Artwork.defaultImage {
                return super.image
            }
        }
        if let artistArt = artist?.artwork?.image {
            return artistArt
        }
        return Artwork.defaultImage
    }
    
    var displayString: String {
        return "\(artist?.name ?? "Unknown artist") - \(title ?? "Unknown title")"
    }
    
    var data: NSData? {
        return dataMO?.data
    }

    var isCached: Bool {
        if let _ = dataMO?.data {
            return true
        }
        return false
    }

}

extension Array where Element: Song {
    
    func filterCached() -> [Element] {
        let filteredArray = self.filter { element in
            return element.isCached
        }
        return filteredArray
    }
    
    func filterCustomArt() -> [Element] {
        let filteredArray = self.filter{ element in
            return element.image != Artwork.defaultImage
        }
        return filteredArray
    }
    
}
