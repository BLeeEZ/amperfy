import UIKit
import ID3TagEditor

class EmbeddedArtworkExtractor  {

    let id3TagEditor = ID3TagEditor()
    
    func extractEmbeddedArtwork(library: LibraryStorage, playable: AbstractPlayable, fileData: Data) {
        guard let id3Tag = try? id3TagEditor.read(mp3: fileData) else { return }
        let tagContentReader = ID3TagContentReader(id3Tag: id3Tag)
        let artworks = tagContentReader.attachedPictures()
        // if there is a frontCover artwork take this as embedded artwork
        if let frontCoverArtwork = artworks.lazy.filter({ $0.type == .frontCover }).first,
           let artworkImage = UIImage(data: frontCoverArtwork.picture) {
            saveEmbeddedImageInLibrary(library: library, playable: playable, embeddedImage: artworkImage)
        // take the first other available artwork
        } else if let artworkImage = artworks.lazy.compactMap({ UIImage(data: $0.picture) }).first {
            saveEmbeddedImageInLibrary(library: library, playable: playable, embeddedImage: artworkImage)
        }
    }

    private func saveEmbeddedImageInLibrary(library: LibraryStorage, playable: AbstractPlayable, embeddedImage: UIImage) {
        let embeddedArtwork = library.createEmbeddedArtwork()
        embeddedArtwork.setImage(fromData: embeddedImage.pngData())
        embeddedArtwork.owner = playable
        library.saveContext()
    }
    
}
