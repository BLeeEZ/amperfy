import UIKit

class SongVC: UITableViewController {
    
    var appDelegate: AppDelegate!
    var sections = [AlphabeticSection<Song>]()

    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        sections = AlphabeticSection<Song>.group(appDelegate.library.getSongs())
        tableView.register(nibName: SongTableCell.typeName)
        tableView.rowHeight = SongTableCell.rowHeight
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.tableView.reloadData()
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
        let cell: SongTableCell = dequeueCell(for: tableView, at: indexPath)

        let section = self.sections[indexPath.section]
        let song = section.entries[indexPath.row]
        
        cell.display(song: song, rootView: self)

        return cell
    }
    
    override func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        var indexTitles = [String]()
        for section in sections {
            indexTitles.append(section.sectionName)
        }
        return indexTitles
    }
    
}
