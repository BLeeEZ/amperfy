import Foundation

class LoginCredentials {

    var serverUrl: String
    var username: String
    var password: String
    var passwordHash: String
    var backendApi: BackenApiType 

    init() {
        self.serverUrl = ""
        self.username = ""
        self.password = ""
        self.passwordHash = ""
        self.backendApi = .notDetected
    }

    init(serverUrl: String, username: String, password: String) {
        self.serverUrl = serverUrl
        self.username = username
        self.password = password
        self.passwordHash = StringHasher.sha256(dataString: password)
        self.backendApi = .notDetected
    }

    convenience init(serverUrl: String, username: String, password: String, backendApi: BackenApiType) {
        self.init(serverUrl: serverUrl, username: username, password: password)
        self.backendApi = backendApi
    }
}

