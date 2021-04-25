import UIKit

class GenreDetailVC: UITableViewController {

    var appDelegate: AppDelegate!
    var genre: Genre?

    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        tableView.register(nibName: ArtistTableCell.typeName)
        tableView.register(nibName: AlbumTableCell.typeName)
        tableView.register(nibName: SongTableCell.typeName)
        
        tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.size.width, height: GenreDetailTableHeader.frameHeight + LibraryElementDetailTableHeaderView.frameHeight))
        if let genreDetailTableHeaderView = ViewBuilder<GenreDetailTableHeader>.createFromNib(withinFixedFrame: CGRect(x: 0, y: 0, width: view.bounds.size.width, height: GenreDetailTableHeader.frameHeight)) {
            genreDetailTableHeaderView.prepare(toWorkOn: genre, rootView: self)
            tableView.tableHeaderView?.addSubview(genreDetailTableHeaderView)
        }
        if let libraryElementDetailTableHeaderView = ViewBuilder<LibraryElementDetailTableHeaderView>.createFromNib(withinFixedFrame: CGRect(x: 0, y: GenreDetailTableHeader.frameHeight, width: view.bounds.size.width, height: LibraryElementDetailTableHeaderView.frameHeight)) {
            libraryElementDetailTableHeaderView.prepare(songContainer: genre, with: appDelegate.player)
            tableView.tableHeaderView?.addSubview(libraryElementDetailTableHeaderView)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.tableView.reloadData()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section+1 {
        case LibraryElement.Artist.rawValue:
            return "Artists"
        case LibraryElement.Album.rawValue:
            return "Albums"
        case LibraryElement.Song.rawValue:
            return "Songs"
        default:
            return ""
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section+1 {
        case LibraryElement.Artist.rawValue:
            return genre?.artists.count ?? 0
        case LibraryElement.Album.rawValue:
            return genre?.albums.count ?? 0
        case LibraryElement.Song.rawValue:
            return genre?.songs.count ?? 0
        default:
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section+1 {
        case LibraryElement.Artist.rawValue:
            let cell: ArtistTableCell = dequeueCell(for: tableView, at: indexPath)
            if let artist = genre?.artists[indexPath.row] {
                cell.display(artist: artist)
            }
            return cell
        case LibraryElement.Album.rawValue:
            let cell: AlbumTableCell = dequeueCell(for: tableView, at: indexPath)
            if let album = genre?.albums[indexPath.row] {
                cell.display(album: album)
            }
            return cell
        case LibraryElement.Song.rawValue:
            let cell: SongTableCell = dequeueCell(for: tableView, at: indexPath)
            if let song = genre?.songs[indexPath.row] {
                cell.display(song: song, rootView: self)
            }
            return cell
        default:
            return UITableViewCell()
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch section+1 {
        case LibraryElement.Artist.rawValue:
            return genre?.artists.count != 0 ? CommonScreenOperations.tableSectionHeightLarge : 0
        case LibraryElement.Album.rawValue:
            return genre?.albums.count != 0 ? CommonScreenOperations.tableSectionHeightLarge : 0
        case LibraryElement.Song.rawValue:
            return genre?.songs.count != 0 ? CommonScreenOperations.tableSectionHeightLarge : 0
        default:
            return 0.0
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section+1 {
        case LibraryElement.Artist.rawValue:
            return ArtistTableCell.rowHeight
        case LibraryElement.Album.rawValue:
            return AlbumTableCell.rowHeight
        case LibraryElement.Song.rawValue:
            return SongTableCell.rowHeight
        default:
            return 0.0
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.section+1 {
        case LibraryElement.Artist.rawValue:
            if let artist = genre?.artists[indexPath.row] {
                performSegue(withIdentifier: Segues.toArtistDetail.rawValue, sender: artist)
            }
        case LibraryElement.Album.rawValue:
            if let album = genre?.albums[indexPath.row] {
                performSegue(withIdentifier: Segues.toAlbumDetail.rawValue, sender: album)
            }
        case LibraryElement.Song.rawValue: break
        default: break
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == Segues.toArtistDetail.rawValue {
            let vc = segue.destination as! ArtistDetailVC
            let artist = sender as? Artist
            vc.artist = artist
        }
        if segue.identifier == Segues.toAlbumDetail.rawValue {
            let vc = segue.destination as! AlbumDetailVC
            let album = sender as? Album
            vc.album = album
        }
    }
    
}
