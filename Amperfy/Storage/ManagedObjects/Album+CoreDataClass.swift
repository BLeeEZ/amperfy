import Foundation
import CoreData
import UIKit

@objc(Album)
public class Album: AbstractLibraryEntityMO {

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
    
    var songs: [Song] {
        guard let songsSet = songsMO else { return [Song]() }
        return songsSet.array as! [Song]
    }
    
    var hasCachedSongs: Bool {
        return songs.hasCachedSongs
    }
    
    var isOrphaned: Bool {
        return identifier == "Unknown (Orphaned)"
    }

}
