import Foundation

enum FontBrowserPreferencesCodec {
    static func decode<Value: Decodable>(
        _ type: Value.Type,
        from data: Data?,
        default defaultValue: @autoclosure () -> Value
    ) -> Value {
        guard let data,
              let decoded = try? JSONDecoder().decode(type, from: data) else {
            return defaultValue()
        }
        return decoded
    }

    static func encode<Value: Encodable>(_ value: Value) -> Data? {
        try? JSONEncoder().encode(value)
    }
}
