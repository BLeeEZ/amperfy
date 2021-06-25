import UIKit

class PodcastTableCell: BasicTableCell {
    
    @IBOutlet weak var podcastLabel: UILabel!
    @IBOutlet weak var podcastImage: LibraryEntityImage!
    @IBOutlet weak var infoLabel: UILabel!
    
    static let rowHeight: CGFloat = 48.0 + margin.bottom + margin.top
    
    private var podcast: Podcast!
    
    func display(podcast: Podcast) {
        self.podcast = podcast
        podcastLabel.text = podcast.title
        podcastImage.displayAndUpdate(entity: podcast, via: appDelegate.artworkDownloadManager)
        var infoText = ""
        let episodeCount = podcast.episodes.count
        if episodeCount == 0 {
            infoText += ""
        } else if episodeCount == 1 {
            infoText += "1 Episode"
        } else {
            infoText += "\(episodeCount) Episodes"
        }
        infoLabel.text = infoText
    }

}
