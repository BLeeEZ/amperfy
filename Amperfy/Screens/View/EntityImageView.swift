import Foundation
import UIKit

class ArtworkCollection {
    let defaultImage: UIImage
    let singleImageEntity: AbstractLibraryEntity?
    let quadImageEntity: [AbstractLibraryEntity]?
    
    init(defaultImage: UIImage, singleImageEntity: AbstractLibraryEntity?, quadImageEntity: [AbstractLibraryEntity]? = nil) {
        self.defaultImage = defaultImage
        self.singleImageEntity = singleImageEntity
        self.quadImageEntity = quadImageEntity
    }
}

open class EntityImageView: UIView {
    
    @IBOutlet weak var singleImage: LibraryEntityImage!
    @IBOutlet weak var quadImage1: LibraryEntityImage!
    @IBOutlet weak var quadImage2: LibraryEntityImage!
    @IBOutlet weak var quadImage3: LibraryEntityImage!
    @IBOutlet weak var quadImage4: LibraryEntityImage!
    
    private var view: UIView!
    
    private var quadImages: [LibraryEntityImage] {
        return [
            quadImage1,
            quadImage2,
            quadImage3,
            quadImage4
        ]
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        loadViewFromNib()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        loadViewFromNib()
    }

    func loadViewFromNib() {
        let bundle = Bundle(for: type(of: self))
        let nib = UINib(nibName: String(describing: type(of: self)), bundle: bundle)
        let view = nib.instantiate(withOwner: self, options: nil).first as! UIView
        view.frame = bounds
        view.autoresizingMask = [
            UIView.AutoresizingMask.flexibleWidth,
            UIView.AutoresizingMask.flexibleHeight
        ]
        addSubview(view)
        self.view = view
    }
    
    func display(container: PlayableContainable) {
        display(collection: container.artworkCollection)
    }

    func configureStyling(image: UIImage, imageSizeType: ArtworkIconSizeType, imageTintColor: UIColor, backgroundColor: UIColor) {
        singleImage.tintColor = imageTintColor
        self.view.backgroundColor = backgroundColor
        self.view.layoutMargins = UIEdgeInsets(top: imageSizeType.rawValue, left: imageSizeType.rawValue, bottom: imageSizeType.rawValue, right: imageSizeType.rawValue)
        let modImage = image.withRenderingMode(.alwaysTemplate)
        singleImage.display(image: modImage)
    }
    
    func display(collection: ArtworkCollection) {
        backgroundColor = .clear
        layer.cornerRadius = RoundedImage.cornerRadius
        layer.masksToBounds = true
        self.view.backgroundColor = .clear
        self.view.layoutMargins = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        quadImages.forEach{ $0.isHidden = true }
        singleImage.isHidden = false
        quadImages[0].layer.maskedCorners = [
            .layerMinXMinYCorner,
            .layerMaxXMinYCorner,
            .layerMinXMaxYCorner,
            .layerMaxXMaxYCorner
        ]
        if let quadEntities = collection.quadImageEntity {
            if quadEntities.count > 1 {
                // check if all images are the same
                if Set(quadEntities.compactMap{$0.artwork?.id}).count == 1 {
                    singleImage.displayAndUpdate(entity: quadEntities.first!)
                } else {
                    singleImage.isHidden = true
                    quadImages.forEach{
                        $0.display(image: UIImage.songArtwork)
                        $0.isHidden = false
                    }
                    for (index, entity) in quadEntities.enumerated() {
                        quadImages[index].display(entity: entity)
                    }
                    quadImages[0].layer.maskedCorners = [.layerMinXMinYCorner]
                    quadImages[1].layer.maskedCorners = [.layerMaxXMinYCorner]
                    quadImages[2].layer.maskedCorners = [.layerMinXMaxYCorner]
                    quadImages[3].layer.maskedCorners = [.layerMaxXMaxYCorner]
                }
            } else if let firstEntity = quadEntities.first  {
                singleImage.displayAndUpdate(entity: firstEntity)
            } else {
                singleImage.display(image: collection.defaultImage)
            }
        } else if let singleEntity = collection.singleImageEntity {
            singleImage.displayAndUpdate(entity: singleEntity)
        } else {
            singleImage.display(image: collection.defaultImage)
        }
    }
    
}
