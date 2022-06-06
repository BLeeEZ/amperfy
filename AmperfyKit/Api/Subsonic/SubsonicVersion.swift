import Foundation

class SubsonicVersion {
    
    static let authenticationTokenRequiredServerApi = SubsonicVersion(major: 1, minor: 13, patch: 0)
    
    let major: Int
    let minor: Int
    let patch: Int
    
    public var description: String { return "\(major).\(minor).\(patch)" }

    init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    convenience init?(_ versionString: String) {
        let splittedVersionString = versionString.components(separatedBy: ".")
        guard splittedVersionString.count == 3 else {
            return nil
        }
        guard let majorInt = Int(splittedVersionString[0]),
          let minorInt = Int(splittedVersionString[1]),
          let patchInt = Int(splittedVersionString[2]),
          majorInt >= 0, minorInt >= 0, patchInt >= 0 else {
            return nil
        }
        self.init(major: majorInt, minor: minorInt, patch: patchInt)
    }

}

extension SubsonicVersion {
    static func == (lhs: SubsonicVersion, rhs: SubsonicVersion) -> Bool {
        return lhs.major == rhs.major && lhs.minor == rhs.minor && lhs.patch == rhs.patch
    }
    
    static func > (lhs: SubsonicVersion, rhs: SubsonicVersion) -> Bool {
        if lhs.major > rhs.major { return true }
        if lhs.minor > rhs.minor { return true }
        if lhs.patch > rhs.patch { return true }
        return false
    }
    static func >= (lhs: SubsonicVersion, rhs: SubsonicVersion) -> Bool {
        if lhs == rhs { return true }
        return lhs > rhs
    }
    
    static func < (lhs: SubsonicVersion, rhs: SubsonicVersion) -> Bool {
        if lhs == rhs { return false }
        return !(lhs > rhs)
    }
    static func <= (lhs: SubsonicVersion, rhs: SubsonicVersion) -> Bool {
        if lhs == rhs { return true }
        return !(lhs > rhs)
    }
}
