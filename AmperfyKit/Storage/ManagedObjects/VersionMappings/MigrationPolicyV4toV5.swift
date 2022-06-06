import Foundation
import CoreData

public class MigrationPolicyV4toV5: NSEntityMigrationPolicy {

    @objc func stringId(forIntId:NSNumber) -> NSString {
        return forIntId.stringValue as NSString
    }

}
