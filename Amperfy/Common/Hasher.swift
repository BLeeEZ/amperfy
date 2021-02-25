import Foundation

class Hasher {

    static func sha256(dataString : String) -> String {
        let data = dataString.data(using: String.Encoding.utf8)! as NSData
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        CC_SHA256(data.bytes, CC_LONG(data.length), &hash)
        
        let resstr = NSMutableString()
        for byte in hash {
            resstr.appendFormat("%02hhx", byte)
        }
        return resstr as String
    }
    
    private static func md5(dataString: String) -> Data {
        let length = Int(CC_MD5_DIGEST_LENGTH)
        let messageData = dataString.data(using:.utf8)!
        var digestData = Data(count: length)

        _ = digestData.withUnsafeMutableBytes { digestBytes -> UInt8 in
            messageData.withUnsafeBytes { messageBytes -> UInt8 in
                if let messageBytesBaseAddress = messageBytes.baseAddress, let digestBytesBlindMemory = digestBytes.bindMemory(to: UInt8.self).baseAddress {
                    let messageLength = CC_LONG(messageData.count)
                    CC_MD5(messageBytesBaseAddress, messageLength, digestBytesBlindMemory)
                }
                return 0
            }
        }
        return digestData
    }
    
    static func md5Hex(dataString: String) -> String {
        return md5(dataString: dataString).map { String(format: "%02hhx", $0) }.joined()
    }
    
    static func md5Base64(dataString: String) -> String {
        return md5(dataString: dataString).base64EncodedString()
    }
    
}
