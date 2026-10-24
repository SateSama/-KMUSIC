import Foundation
import SwiftUI

/// Holds the logged-in server and exposes a client for the views.
@MainActor
final class AppState: ObservableObject {
    @Published private(set) var client: SubsonicClient?

    init() {
        if let saved = Keychain.load() {
            client = SubsonicClient(config: saved)
        }
    }

    /// Checks the credentials with the server and, if they work, remembers them.
    func login(_ config: ServerConfig) async throws {
        let candidate = SubsonicClient(config: config)
        try await candidate.ping()
        Keychain.save(config)
        client = candidate
    }

    func logout() {
        Keychain.clear()
        client = nil
    }
}
