import Foundation
import CryptoKit

/// A small client for the Subsonic REST API (works with Navidrome, Airsonic, Gonic, ...).
struct SubsonicClient {
    let config: ServerConfig

    private var base: String {
        var value = config.url.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.lowercased().hasPrefix("http://") && !value.lowercased().hasPrefix("https://") {
            value = "http://" + value
        }
        while value.hasSuffix("/") { value.removeLast() }
        return value
    }

    // MARK: URL building

    private func authItems() -> [URLQueryItem] {
        let salt = String((0..<12).map { _ in "abcdefghijklmnopqrstuvwxyz0123456789".randomElement()! })
        let digest = Insecure.MD5.hash(data: Data((config.password + salt).utf8))
        let token = digest.map { String(format: "%02x", $0) }.joined()
        return [
            URLQueryItem(name: "u", value: config.username),
            URLQueryItem(name: "t", value: token),
            URLQueryItem(name: "s", value: salt),
            URLQueryItem(name: "v", value: "1.16.1"),
            URLQueryItem(name: "c", value: "KMUSIC"),
            URLQueryItem(name: "f", value: "json"),
        ]
    }

    private func makeURL(_ method: String, _ params: [String: String] = [:]) -> URL? {
        guard var components = URLComponents(string: base + "/rest/" + method + ".view") else { return nil }
        var items = authItems()
        for (key, value) in params.sorted(by: { $0.key < $1.key }) {
            items.append(URLQueryItem(name: key, value: value))
        }
        components.queryItems = items
        return components.url
    }

    func streamURL(for songID: String) -> URL? {
        makeURL("stream", ["id": songID])
    }

    func coverURL(for id: String?, size: Int = 400) -> URL? {
        guard let id, !id.isEmpty else { return nil }
        return makeURL("getCoverArt", ["id": id, "size": String(size)])
    }

    // MARK: Requests

    private func request(_ method: String, _ params: [String: String] = [:]) async throws -> SubsonicResponse {
        guard let url = makeURL(method, params) else { throw SubsonicFailure.badURL }
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw SubsonicFailure.http(http.statusCode)
        }
        let envelope = try JSONDecoder().decode(SubsonicEnvelope.self, from: data)
        if envelope.response.status != "ok" {
            throw SubsonicFailure.server(envelope.response.error?.message ?? "Erreur du serveur.")
        }
        return envelope.response
    }

    func ping() async throws {
        _ = try await request("ping")
    }

    func albums(type: String, offset: Int, size: Int = 60) async throws -> [Album] {
        let response = try await request("getAlbumList2", [
            "type": type,
            "size": String(size),
            "offset": String(offset),
        ])
        return response.albumList2?.album ?? []
    }

    func album(id: String) async throws -> AlbumDetail? {
        try await request("getAlbum", ["id": id]).album
    }

    func search(_ query: String) async throws -> SearchResult {
        let response = try await request("search3", [
            "query": query,
            "artistCount": "0",
            "albumCount": "20",
            "songCount": "30",
        ])
        return response.searchResult3 ?? SearchResult(album: nil, song: nil)
    }
}
