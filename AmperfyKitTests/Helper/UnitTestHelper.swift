import Foundation
import XCTest

extension XCTestCase {
    func getTestFileData(name: String, withExtension: String = "xml") -> Data {
        let bundle = Bundle(for: type(of: self))
        let fileUrl = bundle.url(forResource: name, withExtension: withExtension)
        let data = try! Data(contentsOf: fileUrl!)
        return data
    }
}
