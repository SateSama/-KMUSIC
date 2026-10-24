import SwiftUI

struct SearchView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var player: PlayerManager

    @State private var query = ""
    @State private var albums: [Album] = []
    @State private var songs: [Song] = []
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            List {
                if let errorText {
                    Text(errorText)
                        .foregroundColor(Color.kPrimaryBright)
                        .listRowBackground(Color.kBackground)
                }

                if !albums.isEmpty {
                    Section("Albums") {
                        ForEach(albums) { album in
                            NavigationLink(value: album) {
                                HStack(spacing: 12) {
                                    CoverView(url: app.client?.coverURL(for: album.coverArt, size: 120))
                                        .frame(width: 48, height: 48)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(album.name)
                                            .foregroundColor(Color.kText)
                                            .lineLimit(1)
                                        Text(album.artist ?? "")
                                            .font(.caption)
                                            .foregroundColor(Color.kMuted)
                                            .lineLimit(1)
                                    }
                                }
                            }
                            .listRowBackground(Color.kBackground)
                        }
                    }
                }

                if !songs.isEmpty {
                    Section("Titres") {
                        ForEach(Array(songs.enumerated()), id: \.element.id) { offset, song in
                            Button {
                                if let client = app.client {
                                    player.play(songs, startAt: offset, client: client)
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(song.title)
                                        .foregroundColor(Color.kText)
                                        .lineLimit(1)
                                    Text([song.artist, song.album].compactMap { $0 }.joined(separator: " · "))
                                        .font(.caption)
                                        .foregroundColor(Color.kMuted)
                                        .lineLimit(1)
                                }
                            }
                            .listRowBackground(Color.kBackground)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.kBackground.ignoresSafeArea())
            .navigationTitle("Recherche")
            .navigationDestination(for: Album.self) { album in
                AlbumDetailView(album: album)
            }
            .searchable(text: $query, prompt: "Albums, titres")
            .task(id: query) { await runSearch() }
            .miniPlayerInset()
        }
    }

    private func runSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            albums = []
            songs = []
            errorText = nil
            return
        }
        // Wait a moment so we do not query on every keystroke.
        try? await Task.sleep(nanoseconds: 350_000_000)
        if Task.isCancelled { return }
        guard let client = app.client else { return }
        do {
            let result = try await client.search(trimmed)
            albums = result.album ?? []
            songs = result.song ?? []
            errorText = nil
        } catch is CancellationError {
            return
        } catch {
            if (error as? URLError)?.code == .cancelled { return }
            errorText = error.localizedDescription
        }
    }
}
