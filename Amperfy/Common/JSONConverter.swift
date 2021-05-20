import Foundation

public struct JSONConverter {
    
    public static func decode<T: Decodable>(_ data: Data) throws -> [T]? {
        do {
            let decoded = try JSONDecoder().decode([T].self, from: data)
            return decoded
        } catch {
            throw error
        }
    }

    public static func encode<T: Encodable>(_ value: T) throws -> Data? {
        do {
            let data = try JSONEncoder().encode(value)
            return data
        } catch {
            throw error
        }
    }

}

extension Encodable {

    func asJSONData() -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        return try? encoder.encode(self)
    }
    
    func asJSONString() -> String {
        guard let jsonData = asJSONData() else { return "<no serialized description>" }
        return String(decoding: jsonData, as: UTF8.self)
    }

}
