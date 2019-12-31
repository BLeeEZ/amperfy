import Foundation
import CoreData

@objc(Artist)
public class Artist: AbstractLibraryEntityMO {

    override var identifier: String {
        return name ?? ""
    }
    
    var songs: [Song] {
        guard let songsSet = songsMO else { return [Song]() }
        return songsSet.array as! [Song]
    }
    
    var hasCachedSongs: Bool {
        return songs.hasCachedSongs
    }

}
