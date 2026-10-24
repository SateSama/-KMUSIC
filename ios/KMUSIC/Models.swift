import Foundation

/// Connection details for a Subsonic / Navidrome server.
struct ServerConfig: Codable, Equatable {
    var url: String
    var username: String
    var password: String
}

struct Album: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let artist: String?
    let coverArt: String?
    let songCount: Int?
    let year: Int?
}

struct Song: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let artist: String?
    let album: String?
    let coverArt: String?
    let duration: Int?
    let track: Int?
}

// MARK: - Raw API responses

struct SubsonicEnvelope: Decodable {
    let response: SubsonicResponse

    enum CodingKeys: String, CodingKey {
        case response = "subsonic-response"
    }
}

struct SubsonicResponse: Decodable {
    let status: String
    let error: SubsonicError?
    let albumList2: AlbumList?
    let album: AlbumDetail?
    let searchResult3: SearchResult?
}

struct SubsonicError: Decodable {
    let code: Int?
    let message: String?
}

struct AlbumList: Decodable {
    let album: [Album]?
}

struct AlbumDetail: Decodable {
    let id: String
    let name: String
    let artist: String?
    let coverArt: String?
    let year: Int?
    let song: [Song]?
}

struct SearchResult: Decodable {
    let album: [Album]?
    let song: [Song]?
}

enum SubsonicFailure: LocalizedError {
    case badURL
    case server(String)
    case http(Int)

    var errorDescription: String? {
        switch self {
        case .badURL: return "Adresse du serveur invalide."
        case .server(let message): return message
        case .http(let code): return "Le serveur a répondu avec l'erreur \(code)."
        }
    }
}
