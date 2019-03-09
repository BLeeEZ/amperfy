import Foundation
import UIKit
import os.log

extension Bool {
    mutating func toggle() {
        self = !self
    }
}

extension String {
    func isFoundBy(searchText: String) -> Bool {
        return self.lowercased().contains(searchText.lowercased())
    }
}

extension UIColor {
    static var defaultBlue: UIColor {
        return UIView().tintColor
    }
}

extension NSObject {
    class var typeName: String {
        return String(describing: self)
    }
}

extension NSData {
    var sizeInKB: Int {
        return length/1000
    }
    var sizeAsString: String {
        let byteCount = length
        let bcf = ByteCountFormatter()
        bcf.allowedUnits = [.useKB]
        bcf.countStyle = .file
        let string = bcf.string(fromByteCount: Int64(byteCount))
        return string
    }
}

extension Data {
    static func fetch(fromUrlString urlString: String) -> Data? {
        var data: Data? = nil
        guard let url = URL(string: urlString) else {
            return nil
        }
        do {
            let dataFromURL = try Data(contentsOf: url)
            data = dataFromURL
        } catch {}
        return data
    }
    
    var sizeInKB: Int {
        return count/1000
    }
    var sizeAsString: String {
        let byteCount = count
        let bcf = ByteCountFormatter()
        bcf.allowedUnits = [.useKB]
        bcf.countStyle = .file
        let string = bcf.string(fromByteCount: Int64(byteCount))
        return string
    }
}

extension Date {
    var asIso8601String: String {
        let dateFormatter = ISO8601DateFormatter()
        return dateFormatter.string(from: self)
    }
}

extension String {
    var asIso8601Date: Date? {
        let dateFormatter = ISO8601DateFormatter()
        return dateFormatter.date(from: self)
    }
}

extension Array where Element: Equatable {
    func allIndices(of element: Element) -> [Int] {
        return self.enumerated().filter {
            return $0.element == element
        }.map {
            $0.offset
        }
    }
}

extension Array where Element == String {
    func sortAlphabeticallyAscending() -> [String] {
        return self.sorted{ $0.localizedCaseInsensitiveCompare($1) == ComparisonResult.orderedAscending }
    }
    func sortAlphabeticallyDescending() -> [String] {
        return self.sorted{ $0.localizedCaseInsensitiveCompare($1) == ComparisonResult.orderedDescending }
    }
}

extension UIView {
    static let forceTouchClickLimit: Float = 1.0
    
    var is3DTouchAvailable: Bool {
        return  forceTouchCapability() == .available
    }
    
    func forceTouchCapability() -> UIForceTouchCapability {
        return UIApplication.shared.keyWindow?.rootViewController?.traitCollection.forceTouchCapability ?? .unknown
    }
    
    func normalizedForce(touches: Set<UITouch>) -> Float? {
        guard is3DTouchAvailable, let touch = touches.first else { return nil }
        let maximumForce = touch.maximumPossibleForce
        let force = touch.force
        let normalizedForce = (force / maximumForce)
        return Float(normalizedForce)
    }
    
    func isForceClicked(_ touches: Set<UITouch>) -> Bool {
        guard let force = normalizedForce(touches: touches) else { return false }
        if force < UIView.forceTouchClickLimit {
            return false
        } else {
            return true
        }
    }
}

extension UITableViewController {
    func dequeueCell<CellType: UITableViewCell>(for tableView: UITableView, at indexPath: IndexPath) -> CellType {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: CellType.typeName, for: indexPath) as? CellType else {
            os_log(.error, "The dequeued cell is not an instance of %s", CellType.typeName)
            return CellType()
        }
        return cell
    }
}

extension UITableView {
    func register(nibName: String) {
        self.register(UINib(nibName: nibName, bundle: nil), forCellReuseIdentifier: nibName)
    }
}

extension UIImageView {
    func downloaded(from url: URL, contentMode mode: UIView.ContentMode = .scaleAspectFit) {
        contentMode = mode
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard
                let httpURLResponse = response as? HTTPURLResponse, httpURLResponse.statusCode == 200,
                let mimeType = response?.mimeType, mimeType.hasPrefix("image"),
                let data = data, error == nil,
                let image = UIImage(data: data)
                else { return }
            DispatchQueue.main.async() {
                self.image = image
            }
            }.resume()
    }
    func downloaded(from link: String, contentMode mode: UIView.ContentMode = .scaleAspectFit) {
        guard let url = URL(string: link) else { return }
        downloaded(from: url, contentMode: mode)
    }
}
