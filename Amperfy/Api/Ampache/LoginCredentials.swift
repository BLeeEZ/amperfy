import Foundation

class LoginCredentials {

    var serverUrl: String
    var username: String
    var password: String
    var passwordHash: String

    init() {
        self.serverUrl = ""
        self.username = ""
        self.password = ""
        self.passwordHash = ""
    }

    init(serverUrl: String, username: String, password: String) {
        self.serverUrl = serverUrl
        self.username = username
        self.password = password
        self.passwordHash = Hasher.sha256(dataString: password)
    }
}

