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
        do {
            if let data = try JSONConverter.encode(self) {
                return data
            }
        } catch {}
        return nil
    }
    
    func asJSONString() -> String {
        var jsonString = "<no serialized description>"
        guard let jsonData = asJSONData() else { return jsonString }
        do {
            let serialized = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any]
            if let description = serialized?.description  {
                jsonString = description
            }
        } catch {}
        return jsonString
    }

}
