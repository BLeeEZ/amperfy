import Foundation

class LoginCredentials {

    var serverUrl: String
    var username: String
    var passwordHash: String

    init() {
        self.serverUrl = ""
        self.username = ""
        self.passwordHash = ""
    }

    init(serverUrl: String, username: String, passwordHash: String) {
        self.serverUrl = serverUrl
        self.username = username
        self.passwordHash = passwordHash
    }
}

