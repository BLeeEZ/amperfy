import Foundation

public class LoginCredentials {

    public var serverUrl: String
    public var username: String
    public var password: String
    public var passwordHash: String
    public var backendApi: BackenApiType

    public init() {
        self.serverUrl = ""
        self.username = ""
        self.password = ""
        self.passwordHash = ""
        self.backendApi = .notDetected
    }

    public init(serverUrl: String, username: String, password: String) {
        self.serverUrl = serverUrl
        self.username = username
        self.password = password
        self.passwordHash = StringHasher.sha256(dataString: password)
        self.backendApi = .notDetected
    }

    public convenience init(serverUrl: String, username: String, password: String, backendApi: BackenApiType) {
        self.init(serverUrl: serverUrl, username: username, password: password)
        self.backendApi = backendApi
    }
    
    public func changePasswordAndHash(password newPassword: String) {
        self.password = newPassword
        self.passwordHash = StringHasher.sha256(dataString: newPassword)
    }
    
}

