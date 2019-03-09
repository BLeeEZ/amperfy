import UIKit

class ArtistsVC: UITableViewController {

    var appDelegate: AppDelegate!
    var sections = [AlphabeticSection<Artist>]()

    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        sections = AlphabeticSection<Artist>.group(appDelegate.library.getArtists())
        tableView.register(nibName: ArtistTableCell.typeName)
        tableView.rowHeight = ArtistTableCell.rowHeight
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let section = sections[section]
        return section.sectionName
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return CommonScreenOperations.tableSectionHeightLarge
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let section = self.sections[section]
        return section.entries.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: ArtistTableCell = dequeueCell(for: tableView, at: indexPath)

        let section = self.sections[indexPath.section]
        let artist = section.entries[indexPath.row]
        
        cell.display(artist: artist)

        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let section = self.sections[indexPath.section]
        let artist = section.entries[indexPath.row]
        performSegue(withIdentifier: Segues.toArtistDetail.rawValue, sender: artist)
    }
    
    override func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        var indexTitles = [String]()
        for section in sections {
            indexTitles.append(section.sectionName)
        }
        return indexTitles
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == Segues.toArtistDetail.rawValue {
            let vc = segue.destination as! ArtistDetailVC
            let artist = sender as? Artist
            vc.artist = artist
        }
    }
}
