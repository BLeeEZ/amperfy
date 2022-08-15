import Foundation
import CryptoKit

class StringHasher {

    static func sha256(dataString : String) -> String {
        let digest = CryptoKit.SHA256.hash(data: dataString.data(using: .utf8) ?? Data())
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
    
    private static func md5(dataString: String) -> Data {
        let digest = Insecure.MD5.hash(data: dataString.data(using: .utf8) ?? Data())
        return Data(digest)
    }
    
    static func md5Hex(dataString: String) -> String {
        return md5(dataString: dataString).map { String(format: "%02hhx", $0) }.joined()
    }
    
    static func md5Base64(dataString: String) -> String {
        return md5(dataString: dataString).base64EncodedString()
    }
    
}
