import Foundation
import CoreData

@objc(AbstractPlayableMO)
public class AbstractPlayableMO: AbstractLibraryEntityMO {

    func passOwnership(to targetPlayable: AbstractPlayableMO) {
        let playlistItemsCopy = playlistItems?.compactMap{ $0 as? PlaylistItemMO }
        playlistItemsCopy?.forEach{
            $0.playable = targetPlayable
        }
        
        let scrobbleCopy = scrobbleEntries?.compactMap{ $0 as? ScrobbleEntryMO }
        scrobbleCopy?.forEach{
            $0.playable = targetPlayable
        }
        
        if targetPlayable.download == nil {
            targetPlayable.download = self.download
            self.download = nil
        }
        
        if targetPlayable.embeddedArtwork == nil {
            targetPlayable.embeddedArtwork = self.embeddedArtwork
            self.embeddedArtwork = nil
        }
        
        if targetPlayable.file == nil {
            targetPlayable.file = self.file
            self.file = nil
        }
    }
    
}
