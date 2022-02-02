import UIKit

class LibraryEntityImage: RoundedImage, UIArtworkUpdatable {
    
    var entity: AbstractLibraryEntity?
    
    func display(entity: AbstractLibraryEntity) {
        self.entity = entity
        refresh()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        let appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        appDelegate.uiArtworkUpdater.add(image: self)
    }
    
    deinit {
        let appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        appDelegate.uiArtworkUpdater.remove(image: self)
    }
    
    func displayAndUpdate(entity: AbstractLibraryEntity, via artworkDownloadManager: DownloadManageable) {
        display(entity: entity)
        if let artwork = entity.artwork, artwork.status.isDownloadRecommended || Bool.random(probabilityForTrueInPercent: 5) {
            artworkDownloadManager.download(object: artwork)
        }
    }
    
    func refresh() {
        self.image = entity?.image ?? Artwork.defaultImage
    }
    
}
