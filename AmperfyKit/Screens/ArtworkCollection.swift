import Foundation
import UIKit

public class ArtworkCollection {
    let defaultImage: UIImage
    let singleImageEntity: AbstractLibraryEntity?
    let quadImageEntity: [AbstractLibraryEntity]?
    
    init(defaultImage: UIImage, singleImageEntity: AbstractLibraryEntity?, quadImageEntity: [AbstractLibraryEntity]? = nil) {
        self.defaultImage = defaultImage
        self.singleImageEntity = singleImageEntity
        self.quadImageEntity = quadImageEntity
    }
}
