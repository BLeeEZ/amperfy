import UIKit

class RatingView: UIView {
    
    @IBOutlet weak var clearRatingButton: UIButton!
    @IBOutlet weak var starOne: UIButton!
    @IBOutlet weak var starTwo: UIButton!
    @IBOutlet weak var starThree: UIButton!
    @IBOutlet weak var starFour: UIButton!
    @IBOutlet weak var starFive: UIButton!

    static let frameHeight: CGFloat = 35.0

    private var appDelegate: AppDelegate!
    private var libraryEntity: AbstractLibraryEntity?
    
    var activeStarColor: UIColor = .backgroundColor
    var inactiveStarColor: UIColor = .secondaryLabelColor
    
    lazy var stars: [UIButton] = {
        var stars = [UIButton]()
        stars.append(starOne)
        stars.append(starTwo)
        stars.append(starThree)
        stars.append(starFour)
        stars.append(starFive)
        return stars
    }()
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
    }
    
    func display(entity: AbstractLibraryEntity?) {
        libraryEntity = entity
        refresh()
    }
    
    private var ratingSong: Song? {
        if let entity = libraryEntity,
           let playable = entity as? AbstractPlayable,
           let song = playable.asSong {
            return song
        } else {
            return nil
        }
    }
    
    private var ratingAlbum: Album? {
        if let entity = libraryEntity,
           let album = entity as? Album {
            return album
        } else {
            return nil
        }
    }

    private var ratingArtist: Artist? {
        if let entity = libraryEntity,
           let artist = entity as? Artist {
            return artist
        } else {
            return nil
        }
    }
    
    private func refresh() {
        let rating = ratingSong?.rating ?? ratingAlbum?.rating ?? ratingArtist?.rating ?? 0
        for (index, button) in stars.enumerated() {
            if index < rating {
                button.setAttributedTitle(NSMutableAttributedString(string: FontAwesomeIcon.Star.asString, attributes: [NSAttributedString.Key.font: UIFont(name: FontAwesomeIcon.fontNameSolid, size: 30)!]), for: .normal)
            } else {
                button.setAttributedTitle(NSMutableAttributedString(string: FontAwesomeIcon.Star.asString, attributes: [NSAttributedString.Key.font: UIFont(name: FontAwesomeIcon.fontNameRegular, size: 30)!]), for: .normal)
            }
            button.isEnabled = self.appDelegate.persistentStorage.settings.isOnlineMode
            button.setTitleColor(self.appDelegate.persistentStorage.settings.isOnlineMode ? activeStarColor : inactiveStarColor, for: .normal)
            button.tintColor = self.appDelegate.persistentStorage.settings.isOnlineMode ? activeStarColor : inactiveStarColor
        }
        clearRatingButton.isEnabled = self.appDelegate.persistentStorage.settings.isOnlineMode
    }
    
    private func setRating(rating: Int) {
        guard self.appDelegate.persistentStorage.settings.isOnlineMode else { return }
        appDelegate.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
            let syncLibrary = LibraryStorage(context: context)
            let syncer = self.appDelegate.backendProxy.createLibrarySyncer()
            if let song = self.ratingSong {
                let songAsync = Song(managedObject: context.object(with: song.managedObject.objectID) as! SongMO)
                syncer.setRating(song: songAsync, rating: rating)
                songAsync.rating = rating
            } else if let album = self.ratingAlbum {
                let albumAsync = Album(managedObject: context.object(with: album.managedObject.objectID) as! AlbumMO)
                syncer.setRating(album: albumAsync, rating: rating)
                albumAsync.rating = rating
            } else if let artist = self.ratingArtist {
                let artistAsync = Artist(managedObject: context.object(with: artist.managedObject.objectID) as! ArtistMO)
                syncer.setRating(artist: artistAsync, rating: rating)
                artistAsync.rating = rating
            }
            syncLibrary.saveContext()
            DispatchQueue.main.async {
                self.refresh()
            }
        }
    }

    @IBAction func clearRatingPressed(_ sender: Any) {
        setRating(rating: 0)
    }
    
    @IBAction func starOnePressed(_ sender: Any) {
        setRating(rating: 1)
    }
    
    @IBAction func starTwoPressed(_ sender: Any) {
        setRating(rating: 2)
    }

    @IBAction func starThreePressed(_ sender: Any) {
        setRating(rating: 3)
    }

    @IBAction func starFourPressed(_ sender: Any) {
        setRating(rating: 4)
    }

    @IBAction func starFivePressed(_ sender: Any) {
        setRating(rating: 5)
    }
}
