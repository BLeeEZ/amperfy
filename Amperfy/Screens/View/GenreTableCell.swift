import UIKit

class GenreTableCell: BasicTableCell {
    
    @IBOutlet weak var genreLabel: UILabel!
    @IBOutlet weak var artworkImage: UIImageView!
    @IBOutlet weak var infoLabel: UILabel!
    
    static let rowHeight: CGFloat = 48.0 + margin.bottom + margin.top
    
    func display(genre: Genre) {
        genreLabel.text = genre.name
        artworkImage.image = genre.image
        var infoText = ""
        if appDelegate.backendProxy.selectedApi == .ampache {
            if genre.artists.count == 1 {
                infoText += "1 Artist"
            } else {
                infoText += "\(genre.artists.count) Artists"
            }
            infoText += " \(CommonString.oneMiddleDot) "
        }
        if genre.albums.count == 1 {
            infoText += "1 Album"
        } else {
            infoText += "\(genre.albums.count) Albums"
        }
        infoText += " \(CommonString.oneMiddleDot) "
        if genre.songs.count == 1 {
            infoText += "1 Song"
        } else {
            infoText += "\(genre.songs.count) Songs"
        }
        infoLabel.text = infoText
    }

}
