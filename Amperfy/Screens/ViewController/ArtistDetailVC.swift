import UIKit

class ArtistDetailVC: UITableViewController {

    var appDelegate: AppDelegate!
    var artist: Artist?

    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        tableView.register(nibName: AlbumTableCell.typeName)
        tableView.register(nibName: SongTableCell.typeName)
        
        tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.size.width, height: ArtistDetailTableHeader.frameHeight + LibraryElementDetailTableHeaderView.frameHeight))
        if let (fixedView, headerView) = ViewBuilder<ArtistDetailTableHeader>.createFromNib(withinFixedFrame: CGRect(x: 0, y: 0, width: view.bounds.size.width, height: ArtistDetailTableHeader.frameHeight)) {
            headerView.prepare(toWorkOnArtist: artist, rootView: self)
            tableView.tableHeaderView?.addSubview(fixedView)
        }
        if let (fixedView, headerView) = ViewBuilder<LibraryElementDetailTableHeaderView>.createFromNib(withinFixedFrame: CGRect(x: 0, y: ArtistDetailTableHeader.frameHeight, width: view.bounds.size.width, height: LibraryElementDetailTableHeaderView.frameHeight)) {
            headerView.prepare(toWorkOnArtist: artist, with: appDelegate.player)
            tableView.tableHeaderView?.addSubview(fixedView)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.tableView.reloadData()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section+1 {
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
        case LibraryElement.Album.rawValue:
            return artist?.albums.count ?? 0
        case LibraryElement.Song.rawValue:
            return artist?.songs.count ?? 0
        default:
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section+1 {
        case LibraryElement.Album.rawValue:
            let cell: AlbumTableCell = dequeueCell(for: tableView, at: indexPath)
            if let album = artist?.albums[indexPath.row] {
                cell.display(album: album)
            }
            return cell
        case LibraryElement.Song.rawValue:
            let cell: SongTableCell = dequeueCell(for: tableView, at: indexPath)
            if let song = artist?.songs[indexPath.row] {
                cell.display(song: song, rootView: self)
            }
            return cell
        default:
            return UITableViewCell()
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch section+1 {
        case LibraryElement.Album.rawValue:
            return artist?.albums.count != 0 ? CommonScreenOperations.tableSectionHeightLarge : 0
        case LibraryElement.Song.rawValue:
            return artist?.songs.count != 0 ? CommonScreenOperations.tableSectionHeightLarge : 0
        default:
            return 0.0
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section+1 {
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
        case LibraryElement.Album.rawValue:
            if let album = artist?.albums[indexPath.row] {
                performSegue(withIdentifier: Segues.toAlbumDetail.rawValue, sender: album)
            }
        case LibraryElement.Song.rawValue: break
        default: break
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == Segues.toAlbumDetail.rawValue {
            let vc = segue.destination as! AlbumDetailVC
            let album = sender as? Album
            vc.album = album
        }
    }
    
}
