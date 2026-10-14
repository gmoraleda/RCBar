import Foundation

// MARK: - RevenueCat API

struct Config: Decodable { let apiKey: String; let projectId: String?; let currency: String? }
struct Revenue: Decodable { let value: Double; let currency: String }
struct Projects: Decodable { struct Item: Decodable { let id: String }; let items: [Item] }
struct Failure: Error { let text: String }

let configPath = NSString("~/.config/rcbar/config.json").expandingTildeInPath

func get<T: Decodable>(_ path: String, key: String) async throws -> T {
    var req = URLRequest(url: URL(string: "https://api.revenuecat.com/v2" + path)!)
    req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
    let (data, resp) = try await URLSession.shared.data(for: req)
    let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
    guard (200..<300).contains(code) else {
        throw Failure(text: "HTTP \(code) \(path.prefix(40))…: \(String(decoding: data.prefix(300), as: UTF8.self))")
    }
    return try JSONDecoder().decode(T.self, from: data)
}
