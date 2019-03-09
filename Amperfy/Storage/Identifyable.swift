import Foundation

protocol Identifyable {
    var identifier: String { get }
}

extension Array where Element: Identifyable {
    
    func filterBy(searchText: String) -> [Element] {
        let filteredArray = self.filter { element in
            return element.identifier.isFoundBy(searchText: searchText)
        }
        return filteredArray
    }
    
    func sortAlphabeticallyAscending() -> [Element] {
        return self.sorted{
            return $0.identifier.localizedCaseInsensitiveCompare($1.identifier) == ComparisonResult.orderedAscending
        }
    }
    
    func sortAlphabeticallyDescending() -> [Element] {
        return self.sorted{
            return $0.identifier.localizedCaseInsensitiveCompare($1.identifier) == ComparisonResult.orderedDescending
        }
    }
    
}
