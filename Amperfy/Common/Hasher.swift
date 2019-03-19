import Foundation

class Hasher {

    static func sha256(dataString : String) -> String {
        let data = dataString.data(using: String.Encoding.ascii)! as NSData
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        CC_SHA256(data.bytes, CC_LONG(data.length), &hash)
        
        let resstr = NSMutableString()
        for byte in hash {
            resstr.appendFormat("%02hhx", byte)
        }
        return resstr as String
    }

}