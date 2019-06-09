import UIKit

class AlbumDetailVC: UITableViewController {

    var appDelegate: AppDelegate!
    var album: Album?

    override func viewDidLoad() {
        super.viewDidLoad() 
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        tableView.register(nibName: SongTableCell.typeName)
        tableView.rowHeight = SongTableCell.rowHeight
        
        tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.size.width, height: AlbumDetailTableHeader.frameHeight + LibraryElementDetailTableHeaderView.frameHeight))
        if let (fixedView, headerView) = ViewBuilder<AlbumDetailTableHeader>.createFromNib(withinFixedFrame: CGRect(x: 0, y: 0, width: view.bounds.size.width, height: AlbumDetailTableHeader.frameHeight)) {
            headerView.prepare(toWorkOnAlbum: album, rootView: self)
            tableView.tableHeaderView?.addSubview(fixedView)
        }
        if let (fixedView, headerView) = ViewBuilder<LibraryElementDetailTableHeaderView>.createFromNib(withinFixedFrame: CGRect(x: 0, y: ArtistDetailTableHeader.frameHeight, width: view.bounds.size.width, height: LibraryElementDetailTableHeaderView.frameHeight)) {
            headerView.prepare(toWorkOnAlbum: album, with: appDelegate.player)
            tableView.tableHeaderView?.addSubview(fixedView)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.tableView.reloadData()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return album?.songs.count ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: SongTableCell = dequeueCell(for: tableView, at: indexPath)
        if let song = album?.songs[indexPath.row] {
            cell.display(song: song, rootView: self)
        }
        return cell
    }
    
}
