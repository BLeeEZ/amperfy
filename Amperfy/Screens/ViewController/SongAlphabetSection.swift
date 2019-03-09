import Foundation

class AlphabeticSection<Element: Identifyable> {

    var sectionName = ""
    var entries = [Element]()
    
    init(sectionName: String, entries: [Element])
    {
        self.sectionName = sectionName
        self.entries = entries
    }

    static func group(_ elements: [Element]) -> [AlphabeticSection<Element>] {
        let groups = Dictionary(grouping: elements) { (element) -> String in
            return determSectionName(element: element.identifier)
        }
        return groups.map { (key, values) -> AlphabeticSection<Element> in
            return AlphabeticSection<Element>(sectionName: key, entries: values.sortAlphabeticallyAscending())
            }.sorted()
    }

    private static func determSectionName(element: String) -> String {
        if let firstLetter = element.first {
            switch firstLetter {
            case "0"..."9":
                return "#"
            case "a"..."z":
                return String(firstLetter).uppercased()
            case "A"..."Z":
                return String(firstLetter)
            default:
                return "?"
            }
        }
        return "?"
    }

}

extension AlphabeticSection: Comparable {

    static func < (lhs: AlphabeticSection, rhs: AlphabeticSection) -> Bool {
        if let lhsFirstChar = lhs.sectionName.first, let rhsFirstChar = rhs.sectionName.first {
            if lhsFirstChar == "#" && rhsFirstChar == "?" {
                return true
            }
            if rhsFirstChar == "#" && lhsFirstChar == "?" {
                return false
            }
            if lhsFirstChar == "#" || lhsFirstChar == "?" {
                return false
            }
            if rhsFirstChar == "#" || rhsFirstChar == "?" {
                return true
            }
            return lhsFirstChar < rhsFirstChar
        } else if lhs.sectionName.first != nil {
            return false
        } else {
            return true
        }
    }
    
    static func == (lhs: AlphabeticSection, rhs: AlphabeticSection) -> Bool {
        return lhs.sectionName == rhs.sectionName
    }
    
}
